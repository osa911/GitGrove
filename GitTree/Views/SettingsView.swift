import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newPath = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            // Scan Paths
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Scan Paths", systemImage: "folder.badge.gearshape")
                        .font(.headline)

                    ForEach(settings.scanPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.body.monospaced())
                            Spacer()
                            Button(action: { settings.removePath(path) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Button(action: { settings.addPathWithBookmark() }) {
                            Label("Add Folder…", systemImage: "folder.badge.plus")
                        }
                        Spacer()
                        Button(action: { settings.promptForFolderAccess() }) {
                            Label("Re-grant Access", systemImage: "lock.open")
                        }
                        .help("Re-select folders to grant file access")
                    }
                }
                .padding(4)
            }

            // Sort
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sort Order", systemImage: "arrow.up.arrow.down")
                        .font(.headline)
                    Picker("Sort by", selection: $settings.sortOrder) {
                        ForEach(AppSettings.SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(4)
            }

            Spacer()
        }
        .padding(20)
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.addPath(url.path)
        }
    }
}
