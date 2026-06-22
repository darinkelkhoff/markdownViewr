import SwiftUI

class LiveContent: ObservableObject {
    @Published var rawMarkdown: String = ""
    var fileWatcher: FileWatcher?

    func startWatching(fileURL: URL) {
        fileWatcher = FileWatcher(url: fileURL) { [weak self, fileURL] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8)
            else { return }
            if text != self.rawMarkdown {
                self.rawMarkdown = text
            }
        }
    }
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editorManager: EditorManager

    @State private var showMissingEditorAlert = false
    @State private var missingEditorName = ""
    @StateObject private var liveContent = LiveContent()
    @StateObject private var findBar = FindBarController()
    @StateObject private var folderAccess = FolderAccessManager()
    @State private var renderedHTML = ""
    @State private var docNeedsImageAccess = false
    @StateObject private var toolbarController = DocumentToolbarController()
    @AppStorage("tocVisible") private var tocVisible = false
    @AppStorage("tocDepth") private var tocDepth = 3
    @AppStorage("tocWidth") private var tocWidth: Double = 220
    @AppStorage("tocWrap") private var tocWrap = false
    @AppStorage("tocBullets") private var tocBullets = false
    @AppStorage("rawVisible") private var rawVisible = false
    @AppStorage("rawWidth") private var rawWidth: Double = 400

    private var currentMarkdown: String {
        liveContent.rawMarkdown.isEmpty ? document.rawMarkdown : liveContent.rawMarkdown
    }

    private func rerender() {
        let html = MarkdownDocument.convertToHTML(
            currentMarkdown,
            frontmatterMode: themeManager.frontmatterMode,
            extensions: themeManager.markdownExtensions
        )
        #if MAS_BUILD
        if folderAccess.hasAccess {
            renderedHTML = ImageInliner.inlineLocalImages(in: html) { path in
                folderAccess.imageData(forRelativePath: path)
            }
            docNeedsImageAccess = false
        } else {
            renderedHTML = html
            // Only prompt for folder access when the document actually has local images.
            docNeedsImageAccess = ImageInliner.containsLocalImage(in: html)
        }
        #else
        renderedHTML = html
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if findBar.isVisible {
                FindBarView(findBar: findBar)
            }
            if docNeedsImageAccess {
                FolderAccessBanner {
                    folderAccess.requestAccess { granted in
                        if granted { rerender() }
                    }
                }
            }
            MarkdownWebView(
                html: renderedHTML,
                themeCSS: themeManager.generateCSS(for: themeManager.activeTheme),
                fileURL: fileURL,
                findBar: findBar,
                tocVisible: tocVisible,
                tocDepth: tocDepth,
                tocWidth: tocWidth,
                tocWrap: tocWrap,
                tocBullets: tocBullets,
                rawSource: currentMarkdown,
                rawVisible: rawVisible,
                rawWidth: rawWidth,
                onTocWidthChange: { tocWidth = $0 },
                onRawWidthChange: { rawWidth = $0 }
            )
        }
        .onReceive(themeManager.$frontmatterMode) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(themeManager.$markdownExtensions) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(liveContent.$rawMarkdown) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findToggle)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.findNext() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.findPrevious() }
        }
        .background(WindowAccessor { window in
            findBar.window = window
            if let window {
                toolbarController.configure(
                    in: window,
                    themeManager: themeManager,
                    editorManager: editorManager,
                    fileURL: fileURL,
                    tocVisible: tocVisible,
                    tocDepth: tocDepth,
                    rawVisible: rawVisible,
                    setTocVisible: { tocVisible = $0 },
                    setTocDepth: { tocDepth = $0 },
                    setRawVisible: { rawVisible = $0 },
                    showMissingEditor: { editorName in
                        missingEditorName = editorName
                        showMissingEditorAlert = true
                    }
                )
            }
        })
        .onAppear {
            liveContent.rawMarkdown = document.rawMarkdown
            if let fileURL {
                // Watching the opened document does not require the folder grant —
                // the document itself is accessible via the document architecture.
                folderAccess.prepare(for: fileURL)
                liveContent.startWatching(fileURL: fileURL)
            }
            rerender()
        }
        .onDisappear {
            liveContent.fileWatcher = nil
        }
        .alert("Editor Not Found", isPresented: $showMissingEditorAlert) {
            Button("Remove from List") {
                editorManager.editors.removeAll { $0.name == missingEditorName }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(missingEditorName)\" could not be found. It may have been moved or uninstalled.")
        }
    }

}

final class DocumentToolbarController: NSObject, ObservableObject, NSToolbarDelegate {
    private weak var themeManager: ThemeManager?
    private weak var editorManager: EditorManager?
    private weak var window: NSWindow?
    private var fileURL: URL?
    private var tocVisible = false
    private var tocDepth = 3
    private var rawVisible = false
    private var setTocVisible: ((Bool) -> Void)?
    private var setTocDepth: ((Int) -> Void)?
    private var setRawVisible: ((Bool) -> Void)?
    private var showMissingEditor: ((String) -> Void)?

    func configure(
        in window: NSWindow,
        themeManager: ThemeManager,
        editorManager: EditorManager,
        fileURL: URL?,
        tocVisible: Bool,
        tocDepth: Int,
        rawVisible: Bool,
        setTocVisible: @escaping (Bool) -> Void,
        setTocDepth: @escaping (Int) -> Void,
        setRawVisible: @escaping (Bool) -> Void,
        showMissingEditor: @escaping (String) -> Void
    ) {
        self.window = window
        self.themeManager = themeManager
        self.editorManager = editorManager
        self.fileURL = fileURL
        self.tocVisible = tocVisible
        self.tocDepth = tocDepth
        self.rawVisible = rawVisible
        self.setTocVisible = setTocVisible
        self.setTocDepth = setTocDepth
        self.setRawVisible = setRawVisible
        self.showMissingEditor = showMissingEditor

        if window.toolbar?.identifier != .documentToolbar || window.toolbar?.delegate !== self {
            let toolbar = NSToolbar(identifier: .documentToolbar)
            toolbar.delegate = self
            toolbar.allowsUserCustomization = true
            toolbar.autosavesConfiguration = true
            toolbar.displayMode = NSToolbar.DisplayMode.default
            window.toolbar = toolbar
        }

        updateVisibleItems()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toc, .tocDepth, .markdownSource, .zoom, .theme, .externalEditor, .space, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toc, .tocDepth, .space, .markdownSource, .zoom, .theme, .externalEditor]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if item.itemIdentifier == .externalEditor {
            return hasValidExternalEditor
        }
        return true
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toc:
            return makeTOCItem()
        case .tocDepth:
            return makeTOCDepthItem()
        case .markdownSource:
            return makeMarkdownSourceItem()
        case .zoom:
            return makeZoomItem()
        case .theme:
            return makeThemeItem()
        case .externalEditor:
            return makeExternalEditorItem()
        default:
            return nil
        }
    }

    private func makeTOCItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .toc)
        item.label = "TOC"
        item.paletteLabel = "TOC"
        item.toolTip = tocVisible ? "Hide Table of Contents" : "Show Table of Contents"
        item.image = NSImage(systemSymbolName: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle", accessibilityDescription: "TOC")
        item.target = self
        item.action = #selector(toggleTOC)
        item.menuFormRepresentation = toolbarMenuItem(title: "TOC", action: #selector(toggleTOC), state: tocVisible ? .on : .off)
        return item
    }

    private func makeTOCDepthItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .tocDepth)
        item.label = "TOC Depth"
        item.paletteLabel = "TOC Depth"
        item.toolTip = "Table of Contents depth"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 62, height: 26), pullsDown: false)
        for depth in 1...6 {
            popup.addItem(withTitle: "H\(depth)")
        }
        popup.selectItem(at: max(0, min(5, tocDepth - 1)))
        popup.isEnabled = tocVisible
        popup.target = self
        popup.action = #selector(tocDepthChanged(_:))
        item.view = popup
        item.menuFormRepresentation = tocDepthMenuItem()
        return item
    }

    private func makeMarkdownSourceItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .markdownSource)
        item.label = "Markdown Source"
        item.paletteLabel = "Markdown Source"
        item.toolTip = rawVisible ? "Hide Markdown Source" : "Show Markdown Source"
        item.image = NSImage(systemSymbolName: rawVisible ? "doc.plaintext.fill" : "doc.plaintext", accessibilityDescription: "Markdown Source")
        item.target = self
        item.action = #selector(toggleMarkdownSource)
        item.menuFormRepresentation = toolbarMenuItem(title: "Markdown Source", action: #selector(toggleMarkdownSource), state: rawVisible ? .on : .off)
        return item
    }

    private func makeZoomItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .zoom)
        item.label = "Zoom"
        item.paletteLabel = "Zoom"
        item.toolTip = "Zoom"
        item.view = zoomControlView()
        item.target = self
        item.action = #selector(showZoomMenuFromToolbar(_:))
        item.menuFormRepresentation = zoomMenuItem()
        return item
    }

    private func makeThemeItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .theme)
        item.label = "Theme"
        item.paletteLabel = "Theme"
        item.toolTip = "Theme"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 26), pullsDown: false)
        for theme in themeManager?.themes ?? [] {
            popup.addItem(withTitle: theme.name)
        }
        popup.selectItem(withTitle: themeManager?.activeThemeName ?? "")
        popup.target = self
        popup.action = #selector(themeChanged(_:))
        item.view = popup
        item.menuFormRepresentation = themeMenuItem()
        return item
    }

    private func makeExternalEditorItem() -> NSToolbarItem {
        let editors = editorManager?.editors ?? []
        let validEditors = editors.filter(\.exists)
        let item = NSToolbarItem(itemIdentifier: .externalEditor)
        item.label = externalEditorLabel
        item.paletteLabel = "Open in Editor"
        item.toolTip = externalEditorHelp
        item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Open in Editor")
        item.target = self
        item.action = #selector(openExternalEditorFromToolbar(_:))
        item.autovalidates = false

        item.isEnabled = !validEditors.isEmpty
        item.view = externalEditorButton(isEnabled: !validEditors.isEmpty)

        if editors.isEmpty || validEditors.isEmpty {
            item.isEnabled = false
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: nil, isEnabled: false)
        } else if validEditors.count == 1 {
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: #selector(openExternalEditorFromToolbar(_:)))
        } else {
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: #selector(openExternalEditorFromToolbar(_:)))
        }
        return item
    }

    private var externalEditorLabel: String {
        let validEditors = editorManager?.editors.filter(\.exists) ?? []
        if validEditors.count == 1 {
            return "Open in \(validEditors[0].name)"
        }
        return "Open in Editor"
    }

    private var hasValidExternalEditor: Bool {
        editorManager?.editors.contains(where: \.exists) == true
    }

    private var externalEditorHelp: String {
        if editorManager?.editors.isEmpty == true {
            return "Configure an external editor in Settings"
        }
        return "Open in external editor"
    }

    private func externalEditorButton(isEnabled: Bool) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Open in Editor") ?? NSImage(),
            target: self,
            action: #selector(openExternalEditorFromToolbar(_:))
        )
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.isEnabled = isEnabled
        button.toolTip = externalEditorHelp
        button.setAccessibilityLabel(externalEditorLabel)
        button.frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        return button
    }

    private func zoomControlView() -> NSView {
        ZoomToolbarControlView(control: zoomSegmentedControl())
    }

    private func zoomSegmentedControl() -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: ["", "\(zoomPercent)%", ""], trackingMode: .momentary, target: self, action: #selector(zoomSegmentSelected(_:)))
        control.segmentStyle = .texturedRounded
        control.setImage(NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out"), forSegment: 0)
        control.setImage(NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In"), forSegment: 2)
        control.setToolTip("Zoom Out", forSegment: 0)
        control.setToolTip("Actual Size", forSegment: 1)
        control.setToolTip("Zoom In", forSegment: 2)
        control.setWidth(28, forSegment: 0)
        control.setWidth(56, forSegment: 1)
        control.setWidth(28, forSegment: 2)
        control.setAccessibilityLabel("Zoom")
        return control
    }

    private var zoomPercent: Int {
        Int(round((themeManager?.zoomScale ?? 1.0) * 100))
    }

    private func zoomMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        item.submenu = zoomMenu()
        return item
    }

    private func zoomMenu() -> NSMenu {
        let menu = NSMenu(title: "Zoom")
        menu.addItem(NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Actual Size", action: #selector(actualSize), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: ""))
        for menuItem in menu.items {
            menuItem.target = self
        }
        return menu
    }

    private func tocDepthMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "TOC Depth", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "TOC Depth")
        for depth in 1...6 {
            let menuItem = NSMenuItem(title: "H\(depth)", action: #selector(setTOCDepthFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = depth
            menuItem.state = tocDepth == depth ? .on : .off
            menu.addItem(menuItem)
        }
        item.submenu = menu
        return item
    }

    private func themeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Theme")
        for theme in themeManager?.themes ?? [] {
            let menuItem = NSMenuItem(title: theme.name, action: #selector(themeChangedFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = theme.name == themeManager?.activeThemeName ? .on : .off
            menu.addItem(menuItem)
        }
        item.submenu = menu
        return item
    }

    private func externalEditorMenu() -> NSMenu {
        let menu = NSMenu(title: "Open in Editor")
        for editor in editorManager?.editors ?? [] {
            let menuItem = NSMenuItem(title: editor.opensFolder ? "\(editor.name) (folder)" : editor.name, action: #selector(openExternalEditorFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = editor.id
            menuItem.isEnabled = editor.exists
            menu.addItem(menuItem)
        }
        return menu
    }

    private func toolbarMenuItem(title: String, action: Selector?, state: NSControl.StateValue = .off, isEnabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state
        item.isEnabled = isEnabled
        return item
    }

    @objc private func showZoomMenuFromToolbar(_ sender: Any?) {
        let menu = zoomMenu()
        if let view = sender as? NSView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
            return
        }

        guard let event = NSApp.currentEvent,
              let contentView = event.window?.contentView
        else { return }
        let point = contentView.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func toggleTOC() {
        setTocVisible?(!tocVisible)
    }

    @objc private func tocDepthChanged(_ sender: NSPopUpButton) {
        setTocDepth?(sender.indexOfSelectedItem + 1)
    }

    @objc private func setTOCDepthFromMenu(_ sender: NSMenuItem) {
        setTocDepth?(sender.tag)
    }

    @objc private func toggleMarkdownSource() {
        setRawVisible?(!rawVisible)
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        themeManager?.activeThemeName = title
    }

    @objc private func themeChangedFromMenu(_ sender: NSMenuItem) {
        themeManager?.activeThemeName = sender.title
    }

    @objc private func openExternalEditorFromToolbar(_ sender: Any?) {
        let validEditors = editorManager?.editors.filter(\.exists) ?? []
        if validEditors.count == 1 {
            open(validEditors[0])
        } else if validEditors.count > 1 {
            showExternalEditorMenu(from: sender)
        }
    }

    @objc private func openExternalEditorFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let editor = editorManager?.editors.first(where: { $0.id == id })
        else { return }
        open(editor)
    }

    private func open(_ editor: EditorConfig) {
        guard let fileURL else { return }
        guard editor.exists else {
            showMissingEditor?(editor.name)
            return
        }
        editorManager?.openFile(fileURL, with: editor)
    }

    private func showExternalEditorMenu(from sender: Any?) {
        let menu = externalEditorMenu()
        if let view = sender as? NSView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
            return
        }

        guard let contentView = window?.contentView else { return }
        let point: NSPoint
        if let event = NSApp.currentEvent, event.window === window {
            point = contentView.convert(event.locationInWindow, from: nil)
        } else if let window {
            point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        } else {
            point = NSPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY)
        }
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func zoomSegmentSelected(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            themeManager?.zoomOut()
        case 1:
            themeManager?.zoomReset()
        case 2:
            themeManager?.zoomIn()
        default:
            break
        }
    }

    @objc private func zoomOut() {
        themeManager?.zoomOut()
    }

    @objc private func actualSize() {
        themeManager?.zoomReset()
    }

    @objc private func zoomIn() {
        themeManager?.zoomIn()
    }

    private func updateVisibleItems() {
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            switch item.itemIdentifier {
            case .toc:
                item.image = NSImage(systemSymbolName: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle", accessibilityDescription: "TOC")
                item.toolTip = tocVisible ? "Hide Table of Contents" : "Show Table of Contents"
                item.menuFormRepresentation = toolbarMenuItem(title: "TOC", action: #selector(toggleTOC), state: tocVisible ? .on : .off)
            case .tocDepth:
                if let popup = item.view as? NSPopUpButton {
                    popup.selectItem(at: max(0, min(5, tocDepth - 1)))
                    popup.isEnabled = tocVisible
                }
                item.menuFormRepresentation = tocDepthMenuItem()
            case .markdownSource:
                item.image = NSImage(systemSymbolName: rawVisible ? "doc.plaintext.fill" : "doc.plaintext", accessibilityDescription: "Markdown Source")
                item.toolTip = rawVisible ? "Hide Markdown Source" : "Show Markdown Source"
                item.menuFormRepresentation = toolbarMenuItem(title: "Markdown Source", action: #selector(toggleMarkdownSource), state: rawVisible ? .on : .off)
            case .zoom:
                item.view = zoomControlView()
                item.menuFormRepresentation = zoomMenuItem()
            case .theme:
                if let popup = item.view as? NSPopUpButton {
                    popup.removeAllItems()
                    for theme in themeManager?.themes ?? [] {
                        popup.addItem(withTitle: theme.name)
                    }
                    popup.selectItem(withTitle: themeManager?.activeThemeName ?? "")
                }
                item.menuFormRepresentation = themeMenuItem()
            case .externalEditor:
                let replacement = makeExternalEditorItem()
                item.label = replacement.label
                item.paletteLabel = replacement.paletteLabel
                item.toolTip = replacement.toolTip
                item.image = replacement.image
                item.target = replacement.target
                item.action = replacement.action
                item.view = replacement.view
                item.menuFormRepresentation = replacement.menuFormRepresentation
                item.isEnabled = replacement.isEnabled
            default:
                break
            }
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let toc = NSToolbarItem.Identifier("toc")
    static let tocDepth = NSToolbarItem.Identifier("toc-depth")
    static let markdownSource = NSToolbarItem.Identifier("markdown-source")
    static let zoom = NSToolbarItem.Identifier("zoom")
    static let theme = NSToolbarItem.Identifier("theme")
    static let externalEditor = NSToolbarItem.Identifier("external-editor")
}

private extension NSToolbar.Identifier {
    static let documentToolbar = NSToolbar.Identifier("document-toolbar-v2")
}

private final class ZoomToolbarControlView: NSView {
    private let control: NSSegmentedControl

    init(control: NSSegmentedControl) {
        self.control = control
        super.init(frame: NSRect(origin: .zero, size: control.fittingSize))
        addSubview(control)
        setAccessibilityLabel("Zoom")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        control.intrinsicContentSize
    }

    override func layout() {
        super.layout()
        control.frame = bounds
    }
}

private struct FolderAccessBanner: View {
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
            Text("Allow access to this file's folder to show images and auto-reload on changes.")
                .font(.callout)
            Spacer()
            Button("Allow Access…", action: onGrant)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.18))
    }
}

struct FindBarView: View {
    @ObservedObject var findBar: FindBarController

    var body: some View {
        HStack(spacing: 8) {
            FocusableTextField(
                text: $findBar.searchText,
                placeholder: "Find in document...",
                onSubmit: { findBar.findNext() },
                onEscape: { findBar.hide() }
            )
            .frame(maxWidth: 300)

            if let status = findBar.matchStatus, !findBar.searchText.isEmpty {
                Text(status.total == 0 ? "No matches" : "\(status.current) of \(status.total)")
                    .font(.caption)
                    .foregroundStyle(status.total == 0 ? .red : .secondary)
                    .monospacedDigit()
                    .frame(minWidth: 70)
            }

            Button {
                findBar.findPrevious()
            } label: {
                Image(systemName: "chevron.up")
                    .frame(minHeight: 16)
            }
            .disabled(findBar.searchText.isEmpty)

            Button {
                findBar.findNext()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(minHeight: 16)
            }
            .disabled(findBar.searchText.isEmpty)

            Spacer()

            Button("Done") {
                findBar.hide()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onWindow(nsView.window)
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
