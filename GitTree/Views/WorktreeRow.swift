import SwiftUI

struct WorktreeRow: View {
    static let hasCursor: Bool = {
        let paths = ["/usr/local/bin/cursor", "/opt/homebrew/bin/cursor", "/Applications/Cursor.app"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }()

    static let hasClaude: Bool = {
        let paths = ["/usr/local/bin/claude", "/opt/homebrew/bin/claude"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }()

    let worktree: Worktree
    let repo: Repository
    let onRemove: () -> Void

    @State private var showRemoveConfirm = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Branch + status
            HStack(spacing: 8) {
                Image(systemName: worktree.isMainWorktree ? "star.fill" : "arrow.triangle.branch")
                    .foregroundColor(worktree.isMainWorktree ? .yellow : .green)
                    .frame(width: 16)

                Text(worktree.branch)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if worktree.isMainWorktree {
                    Text("main")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                if worktree.isDirty {
                    Label("Modified", systemImage: "circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .help("Uncommitted changes")
                }

                Spacer()

                if let size = worktree.diskUsageFormatted {
                    Text(size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }

            // Commit info
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(worktree.relativeDateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !worktree.lastCommitMessage.isEmpty {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(worktree.lastCommitMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Path
            Text(worktree.displayPath)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .textSelection(.enabled)

            // Actions
            HStack(spacing: 12) {
                actionButton("folder", "Open in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktree.path)
                }
                actionButton("terminal", "Open in Terminal") {
                    openInTerminal(worktree.path)
                }
                if Self.hasCursor {
                    actionButton("cursorarrow.click.2", "Open in Cursor") {
                        openInCursor(worktree.path)
                    }
                }
                if Self.hasClaude {
                    actionButton("chevron.left.forwardslash.chevron.right", "Open in Claude") {
                        openInClaude(worktree.path)
                    }
                }
                Spacer()
                if !worktree.isMainWorktree {
                    Button(action: { showRemoveConfirm = true }) {
                        Label("Remove", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .cornerRadius(8)
        .onHover { isHovered = $0 }
        .alert("Remove Worktree?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { onRemove() }
        } message: {
            Text("Remove worktree at \(worktree.displayPath)?\nThis cannot be undone.")
        }
    }

    private func actionButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(label)
    }

    private func openInTerminal(_ path: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Terminal", path]
        try? proc.run()
    }

    private func openInClaude(_ path: String) {
        // Create a temp script that cd's and runs claude
        let tmp = NSTemporaryDirectory() + "gitgrove-claude-\(UUID().uuidString).command"
        let script = "#!/bin/bash\ncd \"\(path)\"\nclaude\n"
        try? script.write(toFile: tmp, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmp)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Terminal", tmp]
        try? proc.run()
    }

    private func openInCursor(_ path: String) {
        let paths = ["/usr/local/bin/cursor", "/opt/homebrew/bin/cursor", "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: p)
                proc.arguments = [path]
                try? proc.run()
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
