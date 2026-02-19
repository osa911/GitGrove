import Foundation
import SwiftUI
import AppKit

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let scanPathsKey = "scanPaths"
    private let sortOrderKey = "sortOrder"
    private let bookmarksKey = "securityBookmarks"
    private let defaultPaths = ["~/Documents/1-my_code"]

    enum SortOrder: String, CaseIterable, Identifiable {
        case repoName = "Repository Name"
        case lastModified = "Last Modified"
        case branchName = "Branch Name"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .repoName: return "textformat.abc"
            case .lastModified: return "clock"
            case .branchName: return "arrow.triangle.branch"
            }
        }
    }

    @Published var scanPaths: [String] {
        didSet { UserDefaults.standard.set(scanPaths, forKey: scanPathsKey) }
    }

    @Published var sortOrder: SortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: sortOrderKey) }
    }

    @Published var hasGrantedAccess: Bool {
        didSet { UserDefaults.standard.set(hasGrantedAccess, forKey: "hasGrantedAccess") }
    }

    private var activeSecurityURLs: [URL] = []

    init() {
        self.scanPaths = UserDefaults.standard.stringArray(forKey: scanPathsKey) ?? defaultPaths
        let raw = UserDefaults.standard.string(forKey: sortOrderKey) ?? SortOrder.repoName.rawValue
        self.sortOrder = SortOrder(rawValue: raw) ?? .repoName
        let stored = UserDefaults.standard.bool(forKey: "hasGrantedAccess")
        self.hasGrantedAccess = stored
        if stored {
            _ = restoreBookmarks()
        }
    }

    // MARK: - Security-Scoped Bookmarks

    func promptForFolderAccess() {
        let panel = NSOpenPanel()
        panel.message = "Select folder(s) containing your git repositories"
        panel.prompt = "Grant Access"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        // Start in ~/Documents if possible
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")

        let response = panel.runModal()
        guard response == .OK else { return }

        var bookmarks: [Data] = []
        var paths: [String] = []

        for url in panel.urls {
            do {
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                bookmarks.append(bookmark)
                paths.append((url.path as NSString).abbreviatingWithTildeInPath)
                // Start accessing immediately
                if url.startAccessingSecurityScopedResource() {
                    activeSecurityURLs.append(url)
                }
            } catch {
                print("Failed to create bookmark for \(url): \(error)")
            }
        }

        if !bookmarks.isEmpty {
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
            scanPaths = paths
            hasGrantedAccess = true
        }
    }

    func restoreBookmarks() -> Bool {
        guard let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return false
        }

        var restored = false
        for data in bookmarks {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if url.startAccessingSecurityScopedResource() {
                    activeSecurityURLs.append(url)
                    restored = true
                }
            } catch {
                print("Failed to restore bookmark: \(error)")
            }
        }
        return restored
    }

    func stopAccessingResources() {
        for url in activeSecurityURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityURLs.removeAll()
    }

    // MARK: - Path Management

    func addPath(_ path: String) {
        let p = (path as NSString).abbreviatingWithTildeInPath
        if !scanPaths.contains(p) {
            scanPaths.append(p)
        }
    }

    func addPathWithBookmark() {
        let panel = NSOpenPanel()
        panel.message = "Select a folder to scan for git repositories"
        panel.prompt = "Add Folder"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
            bookmarks.append(bookmark)
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)

            if url.startAccessingSecurityScopedResource() {
                activeSecurityURLs.append(url)
            }
            addPath(url.path)
        } catch {
            print("Failed to bookmark: \(error)")
        }
    }

    func removePath(_ path: String) {
        scanPaths.removeAll { $0 == path }
    }

    func expandedPaths() -> [String] {
        scanPaths.map { NSString(string: $0).expandingTildeInPath }
    }
}
