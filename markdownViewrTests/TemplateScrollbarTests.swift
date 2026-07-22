import XCTest
@testable import markdownViewr

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
        XCTAssertTrue(prunerSource.contains("NSMenu.didBeginTrackingNotification"))
        XCTAssertFalse(prunerSource.contains("NSMenuDelegate"))
        XCTAssertFalse(prunerSource.contains(".delegate = self"))
        XCTAssertFalse(prunerSource.contains("func menuNeedsUpdate"))
        XCTAssertFalse(prunerSource.contains("func applicationWillUpdate"))
        XCTAssertFalse(prunerSource.contains("func menuWillOpen"))
    }

    func testExternalEditorCommandIsSeparatedBelowOpenRecent() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let menuSource = try loadSourceFile("markdownViewr/FileMenuPruner.swift")

        XCTAssertTrue(appSource.contains("ExternalEditorFileMenuController.shared.editorManager = editorManager"))
        XCTAssertTrue(menuSource.contains("ExternalEditorFileMenuController.shared.update(in: fileMenu)"))
        XCTAssertTrue(menuSource.contains(#"normalizedTitle == "Open Recent""#))
        XCTAssertTrue(menuSource.contains("NSMenuItem.separator()"))
        XCTAssertTrue(menuSource.contains("ExternalEditorFileMenuController.currentOpenDocumentFileURL()"))
        XCTAssertTrue(menuSource.contains("window?.isVisible == true"))
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
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertFalse(appSource.contains(#"@AppStorage("tocVisible")"#))
        XCTAssertFalse(appSource.contains(#"@AppStorage("rawVisible")"#))
        XCTAssertFalse(contentSource.contains(#"@AppStorage("tocVisible")"#))
        XCTAssertFalse(contentSource.contains(#"@AppStorage("rawVisible")"#))
        XCTAssertTrue(contentSource.contains("@State private var tocVisible = false"))
        XCTAssertTrue(contentSource.contains("@State private var rawVisible = false"))
        XCTAssertTrue(contentSource.contains(".focusedSceneValue(\\.documentViewCommands, documentViewCommands)"))
        XCTAssertFalse(contentSource.contains(".focusedValue(\\.documentViewCommands, documentViewCommands)"))
        XCTAssertTrue(appSource.contains("@FocusedValue(\\.documentViewCommands) private var documentViewCommands"))
        XCTAssertTrue(appSource.contains(#"Toggle("Table of Contents", isOn: documentViewCommands?.tocVisible ?? .constant(false))"#))
        XCTAssertTrue(appSource.contains(#"Toggle("Markdown Source", isOn: documentViewCommands?.rawVisible ?? .constant(false))"#))
    }

    func testViewMenuIncludesTableOfContentsDepthSubmenu() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertFalse(appSource.contains(#"@AppStorage("tocDepth")"#))
        XCTAssertFalse(contentSource.contains(#"@AppStorage("tocDepth")"#))
        XCTAssertTrue(contentSource.contains("@State private var tocDepth = 3"))
        XCTAssertTrue(appSource.contains(#"Menu("Table of Contents Depth")"#))
        XCTAssertTrue(appSource.contains(#"ForEach(1...6, id: \.self)"#))
        XCTAssertTrue(appSource.contains("documentViewCommands?.setTocDepth(depth)"))
        XCTAssertTrue(appSource.contains(#"Label("H\(depth)", systemImage: "checkmark")"#))
        XCTAssertFalse(appSource.contains(#"Picker("Table of Contents Depth", selection: $tocDepth)"#))
    }

    func testDocumentViewStateAndZoomAreWindowLocal() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")
        let themeSource = try loadSourceFile("markdownViewr/ThemeManager.swift")

        XCTAssertFalse(contentSource.contains(#"@AppStorage("tocWidth")"#))
        XCTAssertFalse(contentSource.contains(#"@AppStorage("rawWidth")"#))
        XCTAssertTrue(contentSource.contains("@State private var tocWidth: Double = 220"))
        XCTAssertTrue(contentSource.contains("@State private var rawWidth: Double = 400"))
        XCTAssertTrue(contentSource.contains("@State private var zoomScale = 1.0"))
        XCTAssertTrue(contentSource.contains("@State private var activeThemeName: String?"))
        XCTAssertTrue(contentSource.contains("private var activeTheme: Theme"))
        XCTAssertTrue(contentSource.contains("themeManager.generateCSS(for: activeTheme, zoomScale: zoomScale)"))
        XCTAssertTrue(contentSource.contains("activeThemeName = themeManager.activeThemeName"))
        XCTAssertTrue(contentSource.contains("setZoomScale: { zoomScale = $0 }"))
        XCTAssertTrue(contentSource.contains("setActiveThemeName: { activeThemeName = $0 }"))
        XCTAssertTrue(contentSource.contains("zoomScale: Binding("))
        XCTAssertTrue(appSource.contains("documentViewCommands?.zoomIn()"))
        XCTAssertTrue(appSource.contains("documentViewCommands?.zoomOut()"))
        XCTAssertTrue(appSource.contains("documentViewCommands?.zoomReset()"))
        XCTAssertFalse(appSource.contains("themeManager.zoomIn()"))
        XCTAssertFalse(appSource.contains("themeManager.zoomOut()"))
        XCTAssertFalse(appSource.contains("themeManager.zoomReset()"))
        XCTAssertFalse(appSource.contains("themeManager.cycleTheme(direction:"))
        XCTAssertFalse(contentSource.contains("themeManager?.activeThemeName = title"))
        XCTAssertFalse(contentSource.contains("themeManager?.activeThemeName = sender.title"))
        XCTAssertTrue(themeSource.contains("func generateCSS(for theme: Theme, zoomScale: Double) -> String"))
    }

    func testSettingsIncludeNewWindowViewDefaults() throws {
        let settingsSource = try loadSourceFile("markdownViewr/SettingsView.swift")
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")
        let webViewSource = try loadSourceFile("markdownViewr/MarkdownWebView.swift")

        XCTAssertTrue(settingsSource.contains(#"@AppStorage("defaultTocVisible") private var defaultTocVisible = false"#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("defaultTocDepth") private var defaultTocDepth = 3"#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("defaultRawVisible") private var defaultRawVisible = false"#))
        XCTAssertTrue(settingsSource.contains(#"Toggle("Show Table of Contents in new windows", isOn: $defaultTocVisible)"#))
        XCTAssertTrue(settingsSource.contains(#"Picker("Default Table of Contents depth", selection: $defaultTocDepth)"#))
        XCTAssertTrue(settingsSource.contains(#"Toggle("Show Markdown Source in new windows", isOn: $defaultRawVisible)"#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("defaultTocVisible") private var defaultTocVisible = false"#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("defaultTocDepth") private var defaultTocDepth = 3"#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("defaultRawVisible") private var defaultRawVisible = false"#))
        XCTAssertTrue(contentSource.contains("initializeWindowViewStateIfNeeded(windowWidth: Double(window.contentView?.bounds.width ?? 0))"))
        XCTAssertFalse(contentSource.contains(".onAppear {\n            initializeWindowViewStateIfNeeded()"))
        XCTAssertFalse(contentSource.contains("guard windowWidth > 0 else { return }"))
        XCTAssertTrue(contentSource.contains("tocVisible = defaultTocVisible"))
        XCTAssertTrue(contentSource.contains("tocDepth = defaultTocDepth"))
        XCTAssertTrue(contentSource.contains("rawVisible = defaultRawVisible"))
        XCTAssertTrue(contentSource.contains("sizeInitialRawSourceIfNeeded(windowWidth: windowWidth)"))
        XCTAssertTrue(contentSource.contains("guard rawVisible && !hasActivatedRawSource && windowWidth > 0 else { return }"))
        XCTAssertTrue(contentSource.contains("windowWidth: windowWidth"))
        XCTAssertTrue(webViewSource.contains("var isPageLoaded = false"))
        XCTAssertTrue(webViewSource.contains("context.coordinator.isPageLoaded = false"))
        XCTAssertTrue(webViewSource.contains("if !context.coordinator.isPageLoaded {"))
        XCTAssertTrue(webViewSource.contains("context.coordinator.pendingTocVisible = tocVisible"))
        XCTAssertTrue(webViewSource.contains("context.coordinator.pendingRawVisible = rawVisible"))
        XCTAssertTrue(webViewSource.contains("isPageLoaded = true"))
    }

    func testSettingsTabsScrollWhenWindowIsSmall() throws {
        let settingsSource = try loadSourceFile("markdownViewr/SettingsView.swift")
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        XCTAssertTrue(settingsSource.contains("private struct SettingsScrollView<Content: View>: View"))
        XCTAssertTrue(settingsSource.contains("ScrollView(.vertical)"))
        XCTAssertTrue(settingsSource.contains("content\n                .frame(maxWidth: .infinity, alignment: .topLeading)\n                .padding(20)"))
        XCTAssertTrue(settingsSource.contains("SettingsScrollView {\n            VStack(alignment: .leading, spacing: 0) {\n                Text(\"General\")"))
        XCTAssertTrue(settingsSource.contains("SettingsScrollView {\n            VStack(alignment: .leading, spacing: 0) {\n                Text(\"Markdown Extensions\")"))
        XCTAssertFalse(settingsSource.contains("}\n        .padding(20)\n        .onAppear {\n            checkIfDefault()"))
        XCTAssertFalse(settingsSource.contains("}\n        .padding(20)\n    }\n\n    private func extensionRow"))
        XCTAssertTrue(settingsSource.contains("}\n        .padding(20)\n    }\n\n    private var selectedEditorIndex"))
        XCTAssertFalse(settingsSource.contains("struct EditorsSettingsView: View {\n    var body: some View {\n        SettingsScrollView"))
        XCTAssertFalse(settingsSource.contains("struct ThemeSettingsView: View {\n    var body: some View {\n        SettingsScrollView"))
        XCTAssertTrue(appSource.contains("hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 720)"))
        XCTAssertTrue(appSource.contains("contentRect: NSRect(x: 0, y: 0, width: 600, height: 720)"))
        XCTAssertFalse(appSource.contains("hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 600)"))
    }

    func testDocumentWindowsUseLandscapeDefaultSize() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        XCTAssertTrue(appSource.contains(".defaultSize(width: 1100, height: 800)"))
        XCTAssertTrue(appSource.contains("static func defaultDocumentWindowSize(tocVisible: Bool, rawVisible: Bool) -> NSSize"))
        XCTAssertTrue(appSource.contains("let autosaveName = Self.autosaveName(for: fileURL)"))
        XCTAssertTrue(appSource.contains("let restoredFrame = window.setFrameUsingName(autosaveName)"))
        XCTAssertTrue(appSource.contains("window.setContentSize(Self.defaultDocumentWindowSize(tocVisible: defaultTocVisible, rawVisible: defaultRawVisible))"))
        XCTAssertTrue(appSource.contains("window.center()"))
        XCTAssertTrue(appSource.contains("window.setFrameAutosaveName(autosaveName)"))
        XCTAssertTrue(appSource.contains("context.coordinator.configureSavingFrame(for: window, autosaveName: autosaveName)"))
        XCTAssertTrue(appSource.contains("func updateNSView(_ nsView: NSView, context: Context)"))
        XCTAssertTrue(appSource.contains("window.saveFrame(usingName: autosaveName)"))
        XCTAssertTrue(appSource.contains("NSWindow.willCloseNotification"))
        XCTAssertTrue(appSource.contains("NSWindow.didResizeNotification"))
        XCTAssertTrue(appSource.contains("NSWindow.didMoveNotification"))
        XCTAssertFalse(appSource.contains(".defaultSize(width: 700, height: 900)"))
        XCTAssertFalse(appSource.contains("if !window.setFrameAutosaveName(autosaveName)"))
        XCTAssertFalse(appSource.contains("fileURL.path.hashValue"))
    }

    func testDocumentWindowAutosaveNameIsStableAcrossLaunches() {
        let fileURL = URL(fileURLWithPath: "/tmp/My File.md")

        XCTAssertEqual(
            DocumentWindowConfigurator.autosaveName(for: fileURL),
            "doc-%2Ftmp%2FMy%20File.md"
        )
    }

    func testDocumentWindowDefaultWidthAccountsForDefaultSidePanes() {
        XCTAssertEqual(DocumentWindowConfigurator.defaultDocumentWindowSize(tocVisible: false, rawVisible: false), NSSize(width: 1100, height: 800))
        XCTAssertEqual(DocumentWindowConfigurator.defaultDocumentWindowSize(tocVisible: true, rawVisible: false), NSSize(width: 1250, height: 800))
        XCTAssertEqual(DocumentWindowConfigurator.defaultDocumentWindowSize(tocVisible: false, rawVisible: true), NSSize(width: 1350, height: 800))
        XCTAssertEqual(DocumentWindowConfigurator.defaultDocumentWindowSize(tocVisible: true, rawVisible: true), NSSize(width: 1500, height: 800))
    }

    func testDocumentWindowFrameConfigurationSkipsTabbedWindows() {
        XCTAssertTrue(DocumentWindowConfigurator.shouldApplyDocumentFrame(isTabbedWindow: false))
        XCTAssertFalse(DocumentWindowConfigurator.shouldApplyDocumentFrame(isTabbedWindow: true))
    }

    func testInitialSourceWidthUsesHalfAvailableWindowWidth() {
        XCTAssertEqual(
            DocumentViewLayout.initialRawWidth(windowWidth: 1200, tocVisible: false, tocWidth: 300),
            600
        )
        XCTAssertEqual(
            DocumentViewLayout.initialRawWidth(windowWidth: 1200, tocVisible: true, tocWidth: 300),
            450
        )
        XCTAssertEqual(
            DocumentViewLayout.initialRawWidth(windowWidth: 380, tocVisible: true, tocWidth: 260),
            220
        )
        XCTAssertEqual(
            DocumentViewLayout.initialRawWidth(windowWidth: 1500, tocVisible: true, tocWidth: 220),
            640
        )
    }

    func testSourceWidthOnlyAutoSizesOnFirstActivation() {
        XCTAssertEqual(
            DocumentViewLayout.rawWidthWhenActivating(
                currentRawWidth: 360,
                hasActivatedRawSource: false,
                windowWidth: 1200,
                tocVisible: true,
                tocWidth: 300
            ),
            450
        )
        XCTAssertEqual(
            DocumentViewLayout.rawWidthWhenActivating(
                currentRawWidth: 360,
                hasActivatedRawSource: true,
                windowWidth: 1200,
                tocVisible: true,
                tocWidth: 300
            ),
            360
        )
    }

    func testViewAndExternalEditorCommandsHaveKeyboardShortcuts() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")
        let menuSource = try loadSourceFile("markdownViewr/FileMenuPruner.swift")

        XCTAssertTrue(appSource.contains(#".keyboardShortcut("t", modifiers: .command)"#))
        XCTAssertTrue(appSource.contains(#".keyboardShortcut("u", modifiers: .command)"#))
        XCTAssertFalse(appSource.contains(#".keyboardShortcut("m", modifiers: .command)"#))
        XCTAssertFalse(appSource.contains(#".keyboardShortcut("m", modifiers: [.command, .shift])"#))
        XCTAssertTrue(menuSource.contains(#"keyEquivalent: "e""#))
        XCTAssertTrue(menuSource.contains("makeEditorMenuItem(title: title, editor: editor, keyEquivalent: \"e\", isEnabled: hasOpenFile)"))
        XCTAssertTrue(menuSource.contains("keyEquivalent: index == 0 ? \"e\" : \"\""))
        XCTAssertTrue(menuSource.contains("let hasOpenFile = currentFileURLProvider() != nil"))
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
        XCTAssertTrue(contentSource.contains("button.showsBorderOnlyWhileMouseInside = true"))
        XCTAssertFalse(contentSource.contains("button.isBordered = false"))
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
        XCTAssertTrue(contentSource.contains(#"NSToolbar.Identifier("document-toolbar-v6")"#))
        XCTAssertTrue(contentSource.contains("removeLegacySavedToolbarConfigurations()"))
        XCTAssertTrue(contentSource.contains(#""NSToolbar Configuration \(identifier)""#))
        XCTAssertTrue(contentSource.contains(#""document-toolbar-v5""#))
        XCTAssertTrue(contentSource.contains(#""document-toolbar-v4""#))
        XCTAssertFalse(contentSource.contains(#"NSToolbar.Identifier("document-toolbar-v5")"#))
        XCTAssertTrue(contentSource.contains("} else if window.toolbar?.delegate !== self {\n            window.toolbar?.delegate = self\n        }"))
        XCTAssertTrue(contentSource.contains("item.target = self"))
        XCTAssertTrue(contentSource.contains("toolbarAllowedItemIdentifiers"))
        XCTAssertTrue(contentSource.contains("toolbarDefaultItemIdentifiers"))
    }

    func testDocumentToolbarUsesNativeRepeatableSpaceItem() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertTrue(contentSource.contains(".space"))
        XCTAssertFalse(contentSource.contains(".flexibleSpace"))
        XCTAssertTrue(contentSource.contains("return [.toc, .tocDepth, .markdownSource, .zoom, .theme, .externalEditor, .space]"))
        XCTAssertTrue(contentSource.contains("return [.toc, .tocDepth, .space, .markdownSource, .zoom, .theme, .externalEditor]"))
        XCTAssertFalse(contentSource.contains("case .fixedSpace:"))
        XCTAssertFalse(contentSource.contains("makeFixedSpaceItem"))
        XCTAssertFalse(contentSource.contains(#"NSToolbarItem.Identifier("document-fixed-space")"#))
        XCTAssertFalse(contentSource.contains("Small Space"))
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
