import AppKit
import Combine

enum FileMenuPruner {
    private static let removedTitles: Set<String> = ["New", "Save", "Save...", "Revert To"]

    static func removeEditingItems(from menu: NSMenu) {
        for item in menu.items.reversed() where shouldRemove(item) {
            menu.removeItem(item)
        }
    }

    static func removeEditingItems(from mainMenu: NSMenu?) {
        guard let fileMenu = fileMenu(in: mainMenu) else { return }
        removeEditingItems(from: fileMenu)
    }

    static func fileMenu(in mainMenu: NSMenu?) -> NSMenu? {
        mainMenu?.item(withTitle: "File")?.submenu
    }

    private static func shouldRemove(_ item: NSMenuItem) -> Bool {
        let title = item.title.replacingOccurrences(of: "…", with: "...").trimmingCharacters(in: .whitespaces)
        return removedTitles.contains(title) || title.hasPrefix("Revert To")
    }
}

final class FileMenuPrunerApplicationDelegate: NSObject, NSApplicationDelegate {
    private var menuObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenuObserver()
        DispatchQueue.main.async {
            self.configureFileMenu()
        }
    }

    deinit {
        if let menuObserver {
            NotificationCenter.default.removeObserver(menuObserver)
        }
    }

    private func installMenuObserver() {
        guard menuObserver == nil else { return }
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let menu = notification.object as? NSMenu,
                  menu === FileMenuPruner.fileMenu(in: NSApp.mainMenu)
            else { return }
            self.updateFileMenu(menu)
        }
    }

    private func configureFileMenu() {
        guard let fileMenu = FileMenuPruner.fileMenu(in: NSApp.mainMenu) else { return }
        updateFileMenu(fileMenu)
    }

    private func updateFileMenu(_ fileMenu: NSMenu) {
        FileMenuPruner.removeEditingItems(from: fileMenu)
        ExternalEditorFileMenuController.shared.update(in: fileMenu)
    }
}

final class ExternalEditorFileMenuController: NSObject, NSMenuItemValidation {
    static let shared = ExternalEditorFileMenuController()

    var currentFileURLProvider: () -> URL? = {
        ExternalEditorFileMenuController.currentOpenDocumentFileURL()
    }

    weak var editorManager: EditorManager? {
        didSet {
            editorSubscription = editorManager?.$editors.sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMainMenu()
                }
            }
            updateMainMenu()
        }
    }

    private let dividerIdentifier = "markdownViewr.externalEditor.divider"
    private let itemIdentifier = "markdownViewr.externalEditor.item"
    private var editorSubscription: AnyCancellable?

    private var dividerMenuIdentifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(dividerIdentifier)
    }

    private var itemMenuIdentifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(itemIdentifier)
    }

    static func currentOpenDocumentFileURL() -> URL? {
        let documentController = NSDocumentController.shared
        return currentOpenDocumentFileURL(in: [documentController.currentDocument] + documentController.documents)
    }

    static func currentOpenDocumentFileURL(in documents: [NSDocument?]) -> URL? {
        for document in documents {
            guard let document else { continue }
            guard document.windowControllers.contains(where: { $0.window?.isVisible == true }) else { continue }
            if let fileURL = document.fileURL {
                return fileURL
            }
        }

        return nil
    }

    func updateMainMenu() {
        guard let fileMenu = FileMenuPruner.fileMenu(in: NSApplication.shared.mainMenu) else { return }
        update(in: fileMenu)
    }

    func update(in menu: NSMenu) {
        removeExistingItems(from: menu)

        let separator = NSMenuItem.separator()
        separator.identifier = dividerMenuIdentifier

        let externalEditorItem = makeExternalEditorItem()
        externalEditorItem.identifier = itemMenuIdentifier

        let insertionIndex = externalEditorInsertionIndex(in: menu)
        menu.insertItem(separator, at: insertionIndex)
        menu.insertItem(externalEditorItem, at: insertionIndex + 1)
    }

    private func makeExternalEditorItem() -> NSMenuItem {
        let editors = editorManager?.editors ?? []
        let hasOpenFile = currentFileURLProvider() != nil

        switch ExternalEditorMenuState(editors: editors) {
        case .disabled:
            let item = NSMenuItem(title: "Open in External Editor", action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item

        case let .single(editor, title):
            return makeEditorMenuItem(title: title, editor: editor, keyEquivalent: "e", isEnabled: hasOpenFile)

        case let .submenu(editors):
            let item = NSMenuItem(title: "Open in External Editor", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Open in External Editor")
            for (index, editor) in editors.enumerated() {
                submenu.addItem(makeEditorMenuItem(
                    title: editor.name,
                    editor: editor,
                    keyEquivalent: index == 0 ? "e" : "",
                    isEnabled: hasOpenFile
                ))
            }
            item.submenu = submenu
            return item
        }
    }

    private func makeEditorMenuItem(
        title: String,
        editor: EditorConfig,
        keyEquivalent: String = "",
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: isEnabled ? #selector(openInExternalEditor(_:)) : nil,
            keyEquivalent: keyEquivalent
        )
        item.target = isEnabled ? self : nil
        item.representedObject = editor.id.uuidString
        item.isEnabled = isEnabled
        item.keyEquivalentModifierMask = [.command]
        return item
    }

    @objc private func openInExternalEditor(_ sender: NSMenuItem) {
        guard let editorIDString = sender.representedObject as? String,
              let editorID = UUID(uuidString: editorIDString),
              let editor = editorManager?.editors.first(where: { $0.id == editorID }),
              let fileURL = currentFileURLProvider()
        else { return }

        editorManager?.openFile(fileURL, with: editor)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.representedObject as? String != nil else { return true }
        return currentFileURLProvider() != nil
    }

    private func removeExistingItems(from menu: NSMenu) {
        for item in menu.items.reversed() {
            if item.identifier == dividerMenuIdentifier || item.identifier == itemMenuIdentifier {
                menu.removeItem(item)
            }
        }
    }

    private func externalEditorInsertionIndex(in menu: NSMenu) -> Int {
        if let openRecentIndex = menu.items.firstIndex(where: { item in
            let normalizedTitle = item.title.replacingOccurrences(of: "…", with: "...").trimmingCharacters(in: .whitespaces)
            return normalizedTitle == "Open Recent"
        }) {
            return openRecentIndex + 1
        }

        return min(menu.items.count, 1)
    }
}
