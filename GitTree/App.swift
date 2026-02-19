import SwiftUI

@main
struct GitGroveApp: App {
    @StateObject private var scanner = GitScanner()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasGrantedAccess {
                    ContentView(scanner: scanner, settings: settings)
                        .frame(minWidth: 700, minHeight: 450)
                } else {
                    OnboardingView(settings: settings, scanner: scanner)
                        .frame(width: 520, height: 480)
                }
            }
            // scan is triggered by ContentView.task
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About GitGrove") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "GitGrove",
                        .applicationVersion: "1.0.0",
                        .version: "1",
                        .credits: {
                            let text = NSMutableAttributedString(
                                string: "See all your git worktrees in one place.\n\nMade by osa911\n\n",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            )
                            let link = NSAttributedString(
                                string: "☕ Buy me a coffee",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .link: URL(string: "https://buymeacoffee.com/osa911")!
                                ]
                            )
                            text.append(link)
                            return text
                        }(),
                        .applicationIcon: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage as Any
                    ])
                }
            }
        }
    }
}
