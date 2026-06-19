import AppKit

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

final class FileMenuPrunerApplicationDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.configureFileMenu()
        }
    }

    func applicationWillUpdate(_ notification: Notification) {
        configureFileMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        FileMenuPruner.removeEditingItems(from: menu)
    }

    private func configureFileMenu() {
        guard let fileMenu = FileMenuPruner.fileMenu(in: NSApp.mainMenu) else { return }
        fileMenu.delegate = self
        FileMenuPruner.removeEditingItems(from: fileMenu)
    }
}
