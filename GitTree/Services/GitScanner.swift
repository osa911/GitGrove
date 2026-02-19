import Foundation

class GitScanner: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var isScanning = false

    private let settings = AppSettings.shared

    init() {
        loadCache()
    }

    private static var cacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GitGrove", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scan-cache.json")
    }

    func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let repos = try? JSONDecoder().decode([Repository].self, from: data) else { return }
        repositories = repos
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(repositories) else { return }
        try? data.write(to: Self.cacheURL)
    }

    @discardableResult
    func scan() async -> [Repository] {
        await MainActor.run { isScanning = true }

        // Restore security bookmarks before scanning
        _ = settings.restoreBookmarks()

        let paths = settings.expandedPaths()
        var foundPaths: Set<String> = []

        for scanPath in paths {
            let gitDirs = findGitRepos(in: scanPath)
            for gitDir in gitDirs {
                foundPaths.insert(gitDir)
                if let repo = await scanRepo(at: gitDir) {
                    await MainActor.run {
                        if let idx = repositories.firstIndex(where: { $0.path == repo.path }) {
                            // Update existing — preserve disk sizes from old data
                            var updated = repo
                            for wi in updated.worktrees.indices {
                                if let oldWt = repositories[idx].worktrees.first(where: { $0.path == updated.worktrees[wi].path }) {
                                    if updated.worktrees[wi].diskUsageBytes == nil {
                                        updated.worktrees[wi].diskUsageBytes = oldWt.diskUsageBytes
                                    }
                                }
                            }
                            repositories[idx] = updated
                        } else {
                            repositories.append(repo)
                        }
                    }
                }
            }
        }

        // Remove stale repos, sort, save
        await MainActor.run {
            repositories.removeAll { !foundPaths.contains($0.path) }
            repositories = sortRepos(repositories)
            isScanning = false
            saveCache()
        }
        return repositories
    }

    private func findGitRepos(in path: String) -> [String] {
        var results: [String] = []
        findGitReposRecursive(path: path, results: &results, depth: 0, maxDepth: 5)
        return results
    }

    private func findGitReposRecursive(path: String, results: inout [String], depth: Int, maxDepth: Int) {
        guard depth <= maxDepth else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return }

        // Check if this directory has a .git file/folder
        if items.contains(".git") {
            results.append(path)
            return // Don't recurse into git repos
        }

        // Recurse into subdirectories (skip heavy ones)
        let skip: Set<String> = ["node_modules", ".build", "Pods", "vendor", "DerivedData", ".Trash", ".git"]
        for item in items {
            if item.hasPrefix(".") || skip.contains(item) { continue }
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                findGitReposRecursive(path: full, results: &results, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }

    private func scanRepo(at path: String) async -> Repository? {
        let worktreeOutput = shell("git", args: ["-C", path, "worktree", "list", "--porcelain"])
        var worktrees = WorktreeParser.parse(porcelainOutput: worktreeOutput, repoPath: path)

        guard !worktrees.isEmpty else { return nil }

        // Enrich each worktree
        for i in worktrees.indices {
            let wt = worktrees[i]
            // Last commit info
            let logOut = shell("git", args: ["-C", wt.path, "log", "-1", "--format=%aI%n%s"])
            let logLines = logOut.components(separatedBy: "\n")
            if logLines.count >= 2 {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                worktrees[i].lastCommitDate = formatter.date(from: logLines[0])
                worktrees[i].lastCommitMessage = logLines[1]
            }

            // Dirty check
            let status = shell("git", args: ["-C", wt.path, "status", "--porcelain", "-uno"])
            worktrees[i].isDirty = !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        }

        let name = URL(fileURLWithPath: path).lastPathComponent
        return Repository(name: name, path: path, worktrees: worktrees)
    }

    /// Compute disk sizes in background after initial scan
    func computeSizes() async {
        // Snapshot current repos to iterate safely
        let snapshot = await MainActor.run { repositories }
        for repo in snapshot {
            for wt in repo.worktrees {
                let duOut = shell("du", args: ["-sk", wt.path])
                if let sizeStr = duOut.split(separator: "\t").first, let kb = Int64(sizeStr) {
                    let bytes = kb * 1024
                    await MainActor.run {
                        guard let ri = repositories.firstIndex(where: { $0.path == repo.path }),
                              let wi = repositories[ri].worktrees.firstIndex(where: { $0.path == wt.path })
                        else { return }
                        repositories[ri].worktrees[wi].diskUsageBytes = bytes
                    }
                }
            }
        }
        await MainActor.run { saveCache() }
    }

    private func shell(_ cmd: String, args: [String]) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/\(cmd)")
        // Try common paths
        if cmd == "du" {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        }
        if cmd == "git" {
            for p in ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"] {
                if FileManager.default.fileExists(atPath: p) {
                    proc.executableURL = URL(fileURLWithPath: p)
                    break
                }
            }
        }
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func directorySize(path: String) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    func sortRepos(_ repos: [Repository]) -> [Repository] {
        switch settings.sortOrder {
        case .repoName:
            return repos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastModified:
            return repos.sorted {
                let d0 = $0.worktrees.compactMap(\.lastCommitDate).max() ?? .distantPast
                let d1 = $1.worktrees.compactMap(\.lastCommitDate).max() ?? .distantPast
                return d0 > d1
            }
        case .branchName:
            return repos.sorted {
                let b0 = $0.worktrees.first?.branch ?? ""
                let b1 = $1.worktrees.first?.branch ?? ""
                return b0.localizedCaseInsensitiveCompare(b1) == .orderedAscending
            }
        }
    }

    func removeWorktree(repo: Repository, worktree: Worktree) {
        guard !worktree.isMainWorktree else { return }
        _ = shell("git", args: ["-C", repo.path, "worktree", "remove", worktree.path])
    }

    func pruneWorktrees(repo: Repository) {
        _ = shell("git", args: ["-C", repo.path, "worktree", "prune"])
    }
}
