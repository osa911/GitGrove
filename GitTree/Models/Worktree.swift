import Foundation

struct Worktree: Identifiable, Hashable, Codable {
    let id: UUID
    let path: String
    let branch: String
    let commitHash: String
    var lastCommitDate: Date?
    var lastCommitMessage: String = ""
    var isDirty: Bool = false
    var diskUsageBytes: Int64?
    var isMainWorktree: Bool = false

    init(path: String, branch: String, commitHash: String, isMainWorktree: Bool = false) {
        self.id = UUID()
        self.path = path
        self.branch = branch
        self.commitHash = commitHash
        self.isMainWorktree = isMainWorktree
    }

    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    var diskUsageFormatted: String? {
        guard let bytes = diskUsageBytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var relativeDateString: String {
        guard let date = lastCommitDate else { return "unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
