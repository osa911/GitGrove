import SwiftUI

struct ContentView: View {
    @ObservedObject var scanner: GitScanner
    @ObservedObject var settings: AppSettings
    @State private var selectedRepo: Repository?
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showQuickSwitcher = false
    @State private var lastScanTime: Date?
    @State private var timer: Timer?
    @State private var fileWatcher: FileWatcher?
    @FocusState private var searchFocused: Bool

    var filteredRepos: [Repository] {
        if searchText.isEmpty { return scanner.repositories }
        let q = searchText.lowercased()
        return scanner.repositories.compactMap { repo in
            let filtered = repo.worktrees.filter {
                $0.branch.lowercased().contains(q) ||
                $0.path.lowercased().contains(q) ||
                $0.lastCommitMessage.lowercased().contains(q) ||
                repo.name.lowercased().contains(q)
            }
            if filtered.isEmpty { return nil }
            var r = repo
            r.worktrees = filtered
            return r
        }
    }

    var totalWorktrees: Int {
        scanner.repositories.flatMap(\.worktrees).count
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .searchable(text: $searchText, prompt: "Filter worktrees…")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
                .frame(minWidth: 400, minHeight: 300)
        }
        .onAppear {
            doScan()
        }
        .onDisappear {
            timer?.invalidate()
            fileWatcher?.stop()
        }
        .overlay(alignment: .bottom) { statusBar }
        .overlay {
            if showQuickSwitcher {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showQuickSwitcher = false }
                QuickSwitcher(
                    repositories: scanner.repositories,
                    onDismiss: { showQuickSwitcher = false }
                )
            }
        }
        .keyboardShortcut(.init("r"), modifiers: .command)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(filteredRepos, selection: $selectedRepo) { repo in
            NavigationLink(value: repo) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.name)
                            .fontWeight(.semibold)
                        Text("\(repo.worktrees.count) worktree\(repo.worktrees.count == 1 ? "" : "s") · \(repo.totalDiskUsageFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 8) }
    }

    // MARK: - Detail

    private var detail: some View {
        Group {
            if let repo = selectedRepo,
               let current = filteredRepos.first(where: { $0.path == repo.path }) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(current.worktrees) { wt in
                            WorktreeRow(worktree: wt, repo: current) {
                                scanner.removeWorktree(repo: current, worktree: wt)
                                doScan()
                            }
                            Divider()
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a repository")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("\(scanner.repositories.count) repos · \(totalWorktrees) worktrees")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: doScan) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(scanner.isScanning)
        }
        ToolbarItem(placement: .primaryAction) {
            Picker("Sort", selection: $settings.sortOrder) {
                ForEach(AppSettings.SortOrder.allCases) { order in
                    Label(order.rawValue, systemImage: order.icon).tag(order)
                }
            }
            .help("Sort repositories")
            .onChange(of: settings.sortOrder) { _ in
                scanner.repositories = scanner.sortRepos(scanner.repositories)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showQuickSwitcher = true }) {
                Label("Quick Switch", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("k", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
        }
        ToolbarItem(placement: .navigation) {
            if scanner.isScanning {
                ProgressView()
                    .scaleEffect(0.7)
                    .help("Scanning…")
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("\(scanner.repositories.count) repos · \(totalWorktrees) worktrees")
            Spacer()
            if let t = lastScanTime {
                Text("Last scan: \(t, style: .relative) ago")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Actions

    private func doScan() {
        Task {
            await scanner.scan()
            lastScanTime = Date()
            await scanner.computeSizes()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            doScan()
        }
    }

    private func startFileWatcher() {
        // Disabled for now — FSEvents + du causes infinite loop
        // Will re-enable with proper debouncing later
    }
}
