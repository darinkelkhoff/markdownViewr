import Foundation
import AppKit

struct EditorConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var opensFolder: Bool

    init(name: String, path: String, opensFolder: Bool = false) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.opensFolder = opensFolder
    }

    var appURL: URL {
        URL(fileURLWithPath: path)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

class EditorManager: ObservableObject {
    @Published var editors: [EditorConfig] {
        didSet {
            save()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "configuredEditors"),
           let decoded = try? JSONDecoder().decode([EditorConfig].self, from: data) {
            self.editors = decoded
        } else {
            self.editors = []
        }
    }

    func addEditor(_ editor: EditorConfig) {
        editors.append(editor)
    }

    func removeEditor(at index: Int) {
        editors.remove(at: index)
    }

    func removeEditor(id: UUID) {
        editors.removeAll { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(editors) {
            UserDefaults.standard.set(data, forKey: "configuredEditors")
        }
    }

    func openFile(_ fileURL: URL, with editor: EditorConfig) {
        let workspace = NSWorkspace.shared
        let appURL = editor.appURL

        guard editor.exists else {
            return
        }

        let urlToOpen = editor.opensFolder
            ? fileURL.deletingLastPathComponent()
            : fileURL

        let config = NSWorkspace.OpenConfiguration()
        workspace.open([urlToOpen], withApplicationAt: appURL, configuration: config)
    }
}
