import XCTest

final class TemplateScrollbarTests: XCTestCase {
    func testTemplateStylesAllScrollbarsWithThemeColors() throws {
        let template = try loadTemplate()
        let rawSourcePreRule = try cssRule("#raw-source pre", in: template)

        XCTAssertTrue(template.contains("::-webkit-scrollbar-track"))
        XCTAssertTrue(template.contains("::-webkit-scrollbar-thumb"))
        XCTAssertTrue(template.contains("::-webkit-scrollbar-thumb:hover"))
        XCTAssertTrue(template.contains("::-webkit-scrollbar-corner"))
        XCTAssertTrue(template.contains("background: var(--bg)"))
        XCTAssertTrue(template.contains("var(--text)"))
        XCTAssertTrue(rawSourcePreRule.contains("border-radius: 0"))
    }

    func testRenderedContentOwnsScrolling() throws {
        let template = try loadTemplate()
        let bodyRule = try cssRule("body", in: template)
        let contentRule = try cssRule("#content", in: template)
        let contentInnerRule = try cssRule("#content-inner", in: template)

        XCTAssertTrue(bodyRule.contains("height: 100vh"))
        XCTAssertTrue(bodyRule.contains("overflow: hidden"))
        XCTAssertTrue(contentRule.contains("height: 100vh"))
        XCTAssertTrue(contentRule.contains("overflow-y: auto"))
        XCTAssertFalse(contentRule.contains("padding:"))
        XCTAssertTrue(contentInnerRule.contains("padding: 32px 48px"))
        XCTAssertTrue(template.contains(#"<div id="content">"#))
        XCTAssertTrue(template.contains(#"<div id="content-inner">"#))
        XCTAssertTrue(template.contains("function _contentScroller()"))
        XCTAssertTrue(template.contains("function _contentContainer()"))
        XCTAssertTrue(template.contains("content.addEventListener('scroll'"))
        XCTAssertFalse(template.contains("window.addEventListener('scroll'"))
        XCTAssertFalse(template.contains("window.scrollTo"))
        XCTAssertFalse(template.contains("window.scrollBy"))
        XCTAssertFalse(template.contains("window.scrollY"))
        XCTAssertFalse(template.contains("document.documentElement.scrollTop"))
    }

    func testActiveTOCLinkIsKeptVisible() throws {
        let template = try loadTemplate()

        XCTAssertTrue(template.contains("function _scrollTOCLinkIntoView(link)"))
        XCTAssertTrue(template.contains("var tocFollowPadding = 24"))
        XCTAssertTrue(template.contains("activeTop < tocTop + tocFollowPadding"))
        XCTAssertTrue(template.contains("activeBottom > tocBottom - tocFollowPadding"))
        XCTAssertTrue(template.contains("toc.scrollTo({ top: targetScrollTop, behavior: 'smooth' })"))
        XCTAssertTrue(template.contains("_scrollTOCLinkIntoView(activeLink)"))
        XCTAssertFalse(template.contains("activeLink.scrollIntoView"))
    }

    func testCSSHelpDocumentsScrollbarSelectors() throws {
        let cssHelp = try loadSourceFile("markdownViewr/CSSHelpView.swift")
        let appHelp = try loadSourceFile("markdownViewr/HelpView.swift")

        XCTAssertTrue(cssHelp.contains("Custom CSS Guide"))
        XCTAssertTrue(cssHelp.contains("#content::-webkit-scrollbar-thumb"))
        XCTAssertTrue(cssHelp.contains("#raw-source::-webkit-scrollbar-thumb"))
        XCTAssertTrue(cssHelp.contains("#toc::-webkit-scrollbar-thumb"))
        XCTAssertTrue(cssHelp.contains("::-webkit-scrollbar-corner"))
        XCTAssertTrue(cssHelp.contains("#content-inner"))
        XCTAssertTrue(cssHelp.contains("nav#toc"))
        XCTAssertTrue(cssHelp.contains("div#raw-source"))
        XCTAssertFalse(cssHelp.contains("Keep readable text centered on wide screens"))
        XCTAssertFalse(cssHelp.contains("Remove heading underlines"))
        XCTAssertTrue(appHelp.contains("Open the CSS Reference"))
        XCTAssertTrue(appHelp.contains("case customCSS"))
        XCTAssertTrue(appHelp.contains("Custom CSS Reference"))
        XCTAssertTrue(appHelp.contains("scrollbar thumbs"))
    }

    func testFileMenuKeepsDefaultCommandGroupsForNonEditingItems() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        XCTAssertFalse(appSource.contains("CommandGroup(replacing: .newItem)"))
        XCTAssertFalse(appSource.contains("CommandGroup(replacing: .saveItem)"))
        XCTAssertTrue(appSource.contains("FileMenuPrunerApplicationDelegate"))

        let prunerSource = try loadSourceFile("markdownViewr/FileMenuPruner.swift")
        XCTAssertTrue(prunerSource.contains("func menuWillOpen"))
    }

    func testExternalEditorCommandIsSeparatedBelowOpenRecent() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let menuSource = try loadSourceFile("markdownViewr/FileMenuPruner.swift")

        XCTAssertTrue(appSource.contains("ExternalEditorFileMenuController.shared.editorManager = editorManager"))
        XCTAssertTrue(menuSource.contains("ExternalEditorFileMenuController.shared.update(in: fileMenu)"))
        XCTAssertTrue(menuSource.contains(#"normalizedTitle == "Open Recent""#))
        XCTAssertTrue(menuSource.contains("NSMenuItem.separator()"))
        XCTAssertTrue(menuSource.contains("NSDocumentController.shared.currentDocument?.fileURL"))
        XCTAssertFalse(appSource.contains(".disabled(fileURL == nil)"))
    }

    func testExternalEditorAddRemoveButtonsUseMatchingSize() throws {
        let settingsSource = try loadSourceFile("markdownViewr/SettingsView.swift")

        XCTAssertTrue(settingsSource.contains("private let editorActionButtonSize"))
        XCTAssertTrue(settingsSource.contains(".frame(width: editorActionButtonSize, height: editorActionButtonSize)"))
    }

    func testExternalEditorSettingsCanReorderConfiguredEditors() throws {
        let settingsSource = try loadSourceFile("markdownViewr/SettingsView.swift")
        let editorSource = try loadSourceFile("markdownViewr/EditorConfig.swift")

        XCTAssertTrue(settingsSource.contains(#"Image(systemName: "chevron.up")"#))
        XCTAssertTrue(settingsSource.contains(#"Image(systemName: "chevron.down")"#))
        XCTAssertTrue(settingsSource.contains("moveSelectedEditor(by: -1)"))
        XCTAssertTrue(settingsSource.contains("moveSelectedEditor(by: 1)"))
        XCTAssertTrue(settingsSource.contains("canMoveSelectedEditorUp"))
        XCTAssertTrue(settingsSource.contains("canMoveSelectedEditorDown"))
        XCTAssertTrue(settingsSource.contains("editorManager.moveEditor(id: selectedEditorID, by: offset)"))
        XCTAssertTrue(editorSource.contains("func moveEditor(id: UUID, by offset: Int)"))
        XCTAssertTrue(editorSource.contains("reorderedEditors.swapAt(source, destination)"))
        XCTAssertTrue(editorSource.contains("editors = reorderedEditors"))
    }

    func testViewMenuIncludesTogglesForTableOfContentsAndMarkdownSource() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        XCTAssertTrue(appSource.contains(#"@AppStorage("tocVisible") private var tocVisible"#))
        XCTAssertTrue(appSource.contains(#"@AppStorage("rawVisible") private var rawVisible"#))
        XCTAssertTrue(appSource.contains(#"Toggle("Table of Contents", isOn: $tocVisible)"#))
        XCTAssertTrue(appSource.contains(#"Toggle("Markdown Source", isOn: $rawVisible)"#))
    }

    func testViewMenuIncludesTableOfContentsDepthSubmenu() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        XCTAssertTrue(appSource.contains(#"@AppStorage("tocDepth") private var tocDepth"#))
        XCTAssertTrue(appSource.contains(#"Menu("Table of Contents Depth")"#))
        XCTAssertTrue(appSource.contains(#"ForEach(1...6, id: \.self)"#))
        XCTAssertTrue(appSource.contains("tocDepth = depth"))
        XCTAssertTrue(appSource.contains(#"Label("H\(depth)", systemImage: "checkmark")"#))
        XCTAssertFalse(appSource.contains(#"Picker("Table of Contents Depth", selection: $tocDepth)"#))
    }

    func testViewAndExternalEditorCommandsHaveKeyboardShortcuts() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let menuSource = try loadSourceFile("markdownViewr/FileMenuPruner.swift")

        XCTAssertTrue(appSource.contains(#".keyboardShortcut("t", modifiers: .command)"#))
        XCTAssertTrue(appSource.contains(#".keyboardShortcut("u", modifiers: .command)"#))
        XCTAssertFalse(appSource.contains(#".keyboardShortcut("m", modifiers: .command)"#))
        XCTAssertFalse(appSource.contains(#".keyboardShortcut("m", modifiers: [.command, .shift])"#))
        XCTAssertTrue(menuSource.contains(#"keyEquivalent: "e""#))
        XCTAssertTrue(menuSource.contains("makeEditorMenuItem(title: title, editor: editor, keyEquivalent: \"e\")"))
        XCTAssertTrue(menuSource.contains("keyEquivalent: index == 0 ? \"e\" : \"\""))
        XCTAssertTrue(menuSource.contains("item.keyEquivalentModifierMask = [.command]"))
    }

    func testToolbarControlsExposeStableTextLabels() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertTrue(contentSource.contains("DocumentToolbarController"))
        XCTAssertTrue(contentSource.contains("static let toc = NSToolbarItem.Identifier(\"toc\")"))
        XCTAssertFalse(contentSource.contains("ToolbarItemGroup(placement: .automatic)"))
        XCTAssertFalse(contentSource.contains(#".toolbar(id: "document-toolbar")"#))
        XCTAssertFalse(contentSource.contains("ToolbarSpacer"))
        XCTAssertFalse(contentSource.contains("tocControls"))
        XCTAssertFalse(contentSource.contains("zoomControls"))
        XCTAssertTrue(contentSource.contains(#"item.label = "TOC""#))
        XCTAssertTrue(contentSource.contains(#"item.label = "TOC Depth""#))
        XCTAssertFalse(contentSource.contains(#"item.label = "Table of Contents Depth""#))
        XCTAssertTrue(contentSource.contains(#"item.label = "Markdown Source""#))
        XCTAssertFalse(contentSource.contains("ToolbarDisplayModeReader"))
        XCTAssertFalse(contentSource.contains("toolbarDisplayMode"))
        XCTAssertFalse(contentSource.contains("zoomTextMenu"))
        XCTAssertTrue(contentSource.contains(#"item.label = "Zoom""#))
        XCTAssertTrue(contentSource.contains("item.menuFormRepresentation = zoomMenuItem()"))
        XCTAssertTrue(contentSource.contains(#"NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")"#))
        XCTAssertTrue(contentSource.contains("item.view = zoomControlView"))
        XCTAssertTrue(contentSource.contains("item.target = self"))
        XCTAssertTrue(contentSource.contains("item.action = #selector(showZoomMenuFromToolbar(_:))"))
        XCTAssertTrue(contentSource.contains("NSSegmentedControl(labels:"))
        XCTAssertTrue(contentSource.contains("final class ZoomToolbarControlView"))
        XCTAssertTrue(contentSource.contains("control.setWidth(56, forSegment: 1)"))
        XCTAssertTrue(contentSource.contains("private func zoomMenu() -> NSMenu"))
        XCTAssertTrue(contentSource.contains("menu.popUp(positioning: nil"))
        XCTAssertTrue(contentSource.contains("showZoomMenuFromToolbar"))
        XCTAssertTrue(contentSource.contains("zoomSegmentSelected"))
        XCTAssertFalse(contentSource.contains("dumpToolbar"))
        XCTAssertFalse(contentSource.contains("toolbar-debug"))
        XCTAssertFalse(contentSource.contains("ControlGroup"))
        XCTAssertTrue(contentSource.contains(#"item.label = "Theme""#))
        XCTAssertTrue(contentSource.contains("item.menuFormRepresentation = themeMenuItem()"))
        XCTAssertTrue(contentSource.contains(#"item.label = externalEditorLabel"#))
        XCTAssertTrue(contentSource.contains("item.action = #selector(openExternalEditorFromToolbar(_:))"))
        XCTAssertTrue(contentSource.contains("item.autovalidates = false"))
        XCTAssertTrue(contentSource.contains("item.view = externalEditorButton(isEnabled: !validEditors.isEmpty)"))
        XCTAssertTrue(contentSource.contains("private func externalEditorButton(isEnabled: Bool) -> NSButton"))
        XCTAssertTrue(contentSource.contains("func validateToolbarItem(_ item: NSToolbarItem) -> Bool"))
        XCTAssertTrue(contentSource.contains("return hasValidExternalEditor"))
        XCTAssertTrue(contentSource.contains("showExternalEditorMenu(from: sender)"))
        XCTAssertFalse(contentSource.contains("externalEditorPopup"))
    }

    func testToolbarIsNativelyCustomizable() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertFalse(appSource.contains("CommandGroup(replacing: .toolbar)"))
        XCTAssertTrue(appSource.contains("CommandGroup(before: .toolbar)"))
        XCTAssertTrue(contentSource.contains("final class DocumentToolbarController: NSObject"))
        XCTAssertTrue(contentSource.contains("ObservableObject"))
        XCTAssertTrue(contentSource.contains("NSToolbarDelegate"))
        XCTAssertTrue(contentSource.contains("window.toolbar = toolbar"))
        XCTAssertTrue(contentSource.contains("toolbar.delegate = self"))
        XCTAssertTrue(contentSource.contains("toolbar.allowsUserCustomization = true"))
        XCTAssertTrue(contentSource.contains("toolbar.autosavesConfiguration = true"))
        XCTAssertTrue(contentSource.contains("toolbar.displayMode = NSToolbar.DisplayMode.default"))
        XCTAssertTrue(contentSource.contains(#"NSToolbar.Identifier("document-toolbar-v2")"#))
        XCTAssertTrue(contentSource.contains("toolbarAllowedItemIdentifiers"))
        XCTAssertTrue(contentSource.contains("toolbarDefaultItemIdentifiers"))
    }

    func testAppKitToolbarCustomizationIncludesRepeatableSpaceItems() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertTrue(contentSource.contains(".space"))
        XCTAssertTrue(contentSource.contains(".flexibleSpace"))
        XCTAssertTrue(contentSource.contains("return [.toc, .tocDepth, .markdownSource, .zoom, .theme, .externalEditor, .space, .flexibleSpace]"))
        XCTAssertTrue(contentSource.contains("return [.toc, .tocDepth, .space, .markdownSource, .zoom, .theme, .externalEditor]"))
    }

    private func loadTemplate() throws -> String {
        let templateURL = try XCTUnwrap(
            Bundle.main.url(forResource: "template", withExtension: "html")
        )
        return try String(contentsOf: templateURL, encoding: .utf8)
    }

    private func loadSourceFile(_ relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func cssRule(_ selector: String, in template: String) throws -> String {
        let start = try XCTUnwrap(template.range(of: "\(selector) {"))
        let remainder = template[start.upperBound...]
        let end = try XCTUnwrap(remainder.firstIndex(of: "}"))
        return String(remainder[..<end])
    }
}
