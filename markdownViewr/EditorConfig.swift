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

enum ExternalEditorMenuState: Equatable {
    case disabled
    case single(EditorConfig, title: String)
    case submenu([EditorConfig])

    init(editors: [EditorConfig]) {
        switch editors.count {
        case 0:
            self = .disabled
        case 1:
            let editor = editors[0]
            self = .single(editor, title: "Open in \(editor.name)")
        default:
            self = .submenu(editors)
        }
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

    func moveEditor(id: UUID, by offset: Int) {
        guard let source = editors.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard editors.indices.contains(destination) else { return }

        var reorderedEditors = editors
        reorderedEditors.swapAt(source, destination)
        editors = reorderedEditors
    }

    func setOpensFolder(_ opensFolder: Bool, for id: UUID) {
        guard let index = editors.firstIndex(where: { $0.id == id }) else { return }
        editors[index].opensFolder = opensFolder
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
