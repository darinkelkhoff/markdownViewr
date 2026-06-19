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
