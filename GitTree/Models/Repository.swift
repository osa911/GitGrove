import Foundation

struct Repository: Identifiable, Hashable, Codable {
    var id: String { path }
    let name: String
    let path: String
    var worktrees: [Worktree]

    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    var totalDiskUsage: Int64 {
        worktrees.compactMap(\.diskUsageBytes).reduce(0, +)
    }

    var totalDiskUsageFormatted: String {
        if worktrees.allSatisfy({ $0.diskUsageBytes == nil }) { return "…" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDiskUsage)
    }

    enum CodingKeys: String, CodingKey {
        case name, path, worktrees
    }
}
