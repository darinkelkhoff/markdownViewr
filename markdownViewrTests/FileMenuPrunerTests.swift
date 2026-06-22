import AppKit
import XCTest
@testable import markdownViewr

final class FileMenuPrunerTests: XCTestCase {
    func testRemovesOnlyRequestedFileMenuItems() {
        let fileMenu = NSMenu(title: "File")
        ["New", "Open...", "Open Recent", "Close", "Save", "Duplicate", "Rename", "Save As...", "Revert To", "Page Setup...", "Print..."]
            .forEach { fileMenu.addItem(withTitle: $0, action: nil, keyEquivalent: "") }

        FileMenuPruner.removeEditingItems(from: fileMenu)

        XCTAssertEqual(
            fileMenu.items.map(\.title),
            ["Open...", "Open Recent", "Close", "Duplicate", "Rename", "Save As...", "Page Setup...", "Print..."]
        )
    }

    func testRemovesSaveWithEllipsisWithoutRemovingSaveAs() {
        let fileMenu = NSMenu(title: "File")
        ["Save...", "Save As...", "Duplicate", "Rename"]
            .forEach { fileMenu.addItem(withTitle: $0, action: nil, keyEquivalent: "") }

        FileMenuPruner.removeEditingItems(from: fileMenu)

        XCTAssertEqual(fileMenu.items.map(\.title), ["Save As...", "Duplicate", "Rename"])
    }

    func testRemovesNestedRevertToSubmenu() {
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open...", action: nil, keyEquivalent: "")
        let revertItem = NSMenuItem(title: "Revert To", action: nil, keyEquivalent: "")
        revertItem.submenu = NSMenu(title: "Revert To")
        fileMenu.addItem(revertItem)
        fileMenu.addItem(withTitle: "Print...", action: nil, keyEquivalent: "")

        FileMenuPruner.removeEditingItems(from: fileMenu)

        XCTAssertEqual(fileMenu.items.map(\.title), ["Open...", "Print..."])
    }
}

final class ExternalEditorMenuStateTests: XCTestCase {
    func testDisabledWhenNoEditorsAreAvailable() {
        let state = ExternalEditorMenuState(editors: [])

        XCTAssertEqual(state, .disabled)
    }

    func testSingleEditorUsesAppNameInTitle() {
        let editor = EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app")
        let state = ExternalEditorMenuState(editors: [editor])

        XCTAssertEqual(state, .single(editor, title: "Open in TextEdit"))
    }

    func testMultipleEditorsUseSubmenu() {
        let textEdit = EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app")
        let code = EditorConfig(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app")
        let state = ExternalEditorMenuState(editors: [textEdit, code])

        XCTAssertEqual(state, .submenu([textEdit, code]))
    }

    func testSingleEditorFileMenuItemKeepsEditorIDForAction() throws {
        let controller = ExternalEditorFileMenuController()
        let manager = EditorManager()
        let editor = EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app")
        manager.editors = [editor]
        controller.editorManager = manager

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")

        controller.update(in: fileMenu)

        let item = try XCTUnwrap(fileMenu.item(withTitle: "Open in TextEdit"))
        XCTAssertEqual(item.representedObject as? String, editor.id.uuidString)
        XCTAssertTrue(item.target === controller)
    }
}
