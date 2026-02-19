import SwiftUI
import AppKit

struct QuickSwitcher: View {
    let repositories: [Repository]
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    private var results: [(repo: Repository, worktree: Worktree)] {
        let q = query.lowercased()
        var matches: [(Repository, Worktree)] = []
        for repo in repositories {
            for wt in repo.worktrees {
                if q.isEmpty ||
                   wt.branch.lowercased().contains(q) ||
                   repo.name.lowercased().contains(q) ||
                   wt.path.lowercased().contains(q) {
                    matches.append((repo, wt))
                }
            }
        }
        return matches
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title3)
                TextField("Jump to worktree…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit { openSelected() }

                Text("⌘K")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Results
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.folder")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No worktrees found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                                QuickSwitcherRow(
                                    repo: item.repo,
                                    worktree: item.worktree,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    openSelected()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { idx in
                        withAnimation { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }

            Divider()

            // Hints bar
            HStack(spacing: 16) {
                hintLabel("↩", "Open in Terminal")
                hintLabel("⌘↩", "Open in Finder")
                if WorktreeRow.hasCursor {
                    hintLabel("⌥↩", "Open in Cursor")
                }
                Spacer()
                hintLabel("esc", "Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 600, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _ in selectedIndex = 0 }
        .onExitCommand { onDismiss() }
        .background(KeyEventHandler(onKeyDown: handleKey))
    }

    private func hintLabel(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(3)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 125: // Down
            selectedIndex = min(selectedIndex + 1, results.count - 1)
            return true
        case 126: // Up
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case 36: // Enter
            if modifiers.contains(.command) {
                openInFinder()
            } else if modifiers.contains(.option) {
                openInCursor()
            } else {
                openSelected()
            }
            return true
        default:
            return false
        }
    }

    private func openSelected() {
        guard selectedIndex < results.count else { return }
        let path = results[selectedIndex].worktree.path
        onDismiss()
        // Open in Terminal
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Terminal", path]
        try? proc.run()
    }

    private func openInFinder() {
        guard selectedIndex < results.count else { return }
        let path = results[selectedIndex].worktree.path
        onDismiss()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func openInCursor() {
        guard selectedIndex < results.count else { return }
        let path = results[selectedIndex].worktree.path
        onDismiss()
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
    }
}

struct QuickSwitcherRow: View {
    let repo: Repository
    let worktree: Worktree
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: worktree.isMainWorktree ? "star.fill" : "arrow.triangle.branch")
                .foregroundColor(worktree.isMainWorktree ? .yellow : .green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(worktree.branch)
                        .fontWeight(.medium)
                    if worktree.isDirty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                    }
                }
                Text(repo.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(worktree.relativeDateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}

// Intercept key events before TextField consumes them
struct KeyEventHandler: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    class KeyEventView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if let handler = onKeyDown, handler(event) { return }
            super.keyDown(with: event)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Monitor key events at the window level
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if let handler = self?.onKeyDown, handler(event) { return nil }
                return event
            }
        }
    }
}
