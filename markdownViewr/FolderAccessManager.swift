import Foundation
import AppKit

/// Owns access to the directory containing the currently-open document. In the MAS
/// (sandboxed) build it resolves or requests a persisted app-scoped security-scoped
/// bookmark for that folder and holds access for the manager's lifetime. In the
/// Developer ID build it is an inert pass-through that always reports access.
final class FolderAccessManager: ObservableObject {
    /// True when the document's folder is accessible (always true in the non-MAS build).
    @Published private(set) var hasAccess: Bool = false

    private var folderURL: URL?
    private var accessedURL: URL?

    deinit {
        accessedURL?.stopAccessingSecurityScopedResource()
    }

    /// Resolves any stored access for the document's folder. Call once when a document opens.
    func prepare(for fileURL: URL) {
        let folder = fileURL.deletingLastPathComponent()
        folderURL = folder
        #if MAS_BUILD
        guard let data = UserDefaults.standard.data(forKey: Self.key(for: folder)) else {
            hasAccess = false
            return
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ), url.startAccessingSecurityScopedResource() else {
            hasAccess = false
            return
        }
        accessedURL = url
        hasAccess = true
        if stale { storeBookmark(for: url) }
        #else
        hasAccess = true
        #endif
    }

    /// Presents a folder picker (MAS only) to obtain and persist access. Calls back on the main queue.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        #if MAS_BUILD
        guard let folder = folderURL else { completion(false); return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.prompt = "Allow Access"
        panel.message = "Allow markdownViewr to access this folder to show images and auto-reload changes."
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  url.startAccessingSecurityScopedResource() else {
                completion(false)
                return
            }
            self.accessedURL?.stopAccessingSecurityScopedResource()
            self.accessedURL = url
            self.storeBookmark(for: url)
            self.hasAccess = true
            completion(true)
        }
        #else
        completion(true)
        #endif
    }

    /// Reads bytes for a path relative to the document's folder, or nil if unavailable.
    /// Used by the MAS render path to inline images. Returns nil when access is not held.
    func imageData(forRelativePath path: String) -> Data? {
        guard hasAccess, let base = accessedURL ?? folderURL else { return nil }
        let url = base.appendingPathComponent(path)
        return try? Data(contentsOf: url)
    }

    #if MAS_BUILD
    private func storeBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        // Key by the document's folder so the same document re-grants silently next launch.
        if let folder = folderURL {
            UserDefaults.standard.set(data, forKey: Self.key(for: folder))
        }
        UserDefaults.standard.set(data, forKey: Self.key(for: url))
    }

    private static func key(for folder: URL) -> String {
        "folderBookmark:\(folder.standardizedFileURL.path)"
    }
    #endif
}
