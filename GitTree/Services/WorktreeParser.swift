import Foundation

struct WorktreeParser {
    static func parse(porcelainOutput: String, repoPath: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        let blocks = porcelainOutput.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            guard !lines.isEmpty else { continue }

            var path = ""
            var branch = ""
            var hash = ""
            var isMain = false

            for line in lines {
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("HEAD ") {
                    hash = String(line.dropFirst("HEAD ".count))
                } else if line.hasPrefix("branch ") {
                    let full = String(line.dropFirst("branch ".count))
                    branch = full.replacingOccurrences(of: "refs/heads/", with: "")
                } else if line == "detached" {
                    branch = "HEAD (detached)"
                } else if line == "bare" {
                    continue
                }
            }

            guard !path.isEmpty, !hash.isEmpty else { continue }
            isMain = path == repoPath
            if branch.isEmpty { branch = String(hash.prefix(8)) }

            worktrees.append(Worktree(
                path: path,
                branch: branch,
                commitHash: hash,
                isMainWorktree: isMain
            ))
        }
        return worktrees
    }
}
