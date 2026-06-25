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
        controller.currentFileURLProvider = { URL(fileURLWithPath: "/tmp/test.md") }

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")

        controller.update(in: fileMenu)

        let item = try XCTUnwrap(fileMenu.item(withTitle: "Open in TextEdit"))
        XCTAssertEqual(item.representedObject as? String, editor.id.uuidString)
        XCTAssertTrue(item.target === controller)
    }

    func testSingleEditorFileMenuItemIsDisabledWithoutOpenFile() throws {
        let controller = ExternalEditorFileMenuController()
        let manager = EditorManager()
        manager.editors = [EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app")]
        controller.editorManager = manager
        controller.currentFileURLProvider = { nil }

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")

        controller.update(in: fileMenu)

        let item = try XCTUnwrap(fileMenu.item(withTitle: "Open in TextEdit"))
        XCTAssertFalse(item.isEnabled)
        XCTAssertNil(item.action)
        XCTAssertNil(item.target)
        XCTAssertFalse(controller.validateMenuItem(item))
    }

    func testExternalEditorSubmenuItemsAreDisabledWithoutOpenFile() throws {
        let controller = ExternalEditorFileMenuController()
        let manager = EditorManager()
        manager.editors = [
            EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app"),
            EditorConfig(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app")
        ]
        controller.editorManager = manager
        controller.currentFileURLProvider = { nil }

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")

        controller.update(in: fileMenu)

        let item = try XCTUnwrap(fileMenu.item(withTitle: "Open in External Editor"))
        let submenu = try XCTUnwrap(item.submenu)
        XCTAssertTrue(item.isEnabled)
        XCTAssertTrue(submenu.items.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(submenu.items.allSatisfy { $0.action == nil })
        XCTAssertTrue(submenu.items.allSatisfy { $0.target == nil })
        XCTAssertTrue(submenu.items.allSatisfy { !controller.validateMenuItem($0) })
    }

    func testExternalEditorMenuItemValidationAllowsOpenFile() throws {
        let controller = ExternalEditorFileMenuController()
        let manager = EditorManager()
        manager.editors = [EditorConfig(name: "TextEdit", path: "/System/Applications/TextEdit.app")]
        controller.editorManager = manager
        controller.currentFileURLProvider = { URL(fileURLWithPath: "/tmp/test.md") }

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")

        controller.update(in: fileMenu)

        let item = try XCTUnwrap(fileMenu.item(withTitle: "Open in TextEdit"))
        XCTAssertEqual(item.action, NSSelectorFromString("openInExternalEditor:"))
        XCTAssertTrue(item.target === controller)
        XCTAssertTrue(controller.validateMenuItem(item))
    }

    func testCurrentOpenDocumentFileURLIgnoresDocumentsWithoutVisibleWindows() {
        let document = NSDocument()
        document.fileURL = URL(fileURLWithPath: "/tmp/closed.md")
        document.addWindowController(NSWindowController(window: TestWindow(isVisibleForTest: false)))

        XCTAssertNil(ExternalEditorFileMenuController.currentOpenDocumentFileURL(in: [document]))
    }

    func testCurrentOpenDocumentFileURLUsesVisibleDocumentWindow() {
        let hiddenDocument = NSDocument()
        hiddenDocument.fileURL = URL(fileURLWithPath: "/tmp/hidden.md")
        hiddenDocument.addWindowController(NSWindowController(window: TestWindow(isVisibleForTest: false)))

        let visibleDocument = NSDocument()
        let visibleURL = URL(fileURLWithPath: "/tmp/visible.md")
        visibleDocument.fileURL = visibleURL
        visibleDocument.addWindowController(NSWindowController(window: TestWindow(isVisibleForTest: true)))

        XCTAssertEqual(
            ExternalEditorFileMenuController.currentOpenDocumentFileURL(in: [hiddenDocument, visibleDocument]),
            visibleURL
        )
    }
}

private final class TestWindow: NSWindow {
    private let isVisibleForTest: Bool

    init(isVisibleForTest: Bool) {
        self.isVisibleForTest = isVisibleForTest
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
    }

    override var isVisible: Bool {
        isVisibleForTest
    }
}
