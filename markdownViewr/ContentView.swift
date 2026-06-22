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
                ZoomToolbarConfigurator.shared.configure(in: window, themeManager: themeManager)
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                tocToggleButton
            }
            ToolbarItem(placement: .automatic) {
                tocDepthPicker
            }
            ToolbarItem(placement: .automatic) {
                rawButton
            }
            ToolbarItem(placement: .automatic) {
                zoomIconControls
            }
            ToolbarItem(placement: .automatic) {
                palettePicker
            }
            ToolbarItem(placement: .automatic) {
                editorButton
            }
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

    private var tocToggleButton: some View {
        Button {
            tocVisible.toggle()
        } label: {
            Label("TOC", systemImage: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle")
        }
        .help(tocVisible ? "Hide Table of Contents" : "Show Table of Contents")
    }

    private var tocDepthPicker: some View {
        Picker("Table of Contents Depth", selection: $tocDepth) {
            Text("H1").tag(1)
            Text("H2").tag(2)
            Text("H3").tag(3)
            Text("H4").tag(4)
            Text("H5").tag(5)
            Text("H6").tag(6)
        }
        .frame(width: 60)
        .disabled(!tocVisible)
        .help("Table of Contents depth")
    }

    private var rawButton: some View {
        Button {
            rawVisible.toggle()
        } label: {
            Label("Markdown Source", systemImage: rawVisible ? "doc.plaintext.fill" : "doc.plaintext")
        }
        .help(rawVisible ? "Hide Markdown Source" : "Show Markdown Source")
    }

    private var zoomIconControls: some View {
        HStack(spacing: 2) {
            Button {
                handleZoomOutToolbarAction()
            } label: {
                Label("Zoom", systemImage: "minus.magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Zoom Out")
            .help("Zoom Out")

            Button {
                themeManager.zoomReset()
            } label: {
                Text("\(Int(themeManager.zoomScale * 100))%")
                    .font(.system(size: 11).monospacedDigit())
                    .frame(width: 38)
            }
            .buttonStyle(.plain)
            .help("Actual Size")

            Button {
                themeManager.zoomIn()
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .help("Zoom In")
        }
        .accessibilityLabel("Zoom")
        .help("Zoom")
    }

    private func handleZoomOutToolbarAction() {
        if NSApp.keyWindow?.toolbar?.displayMode == .labelOnly {
            ZoomToolbarConfigurator.shared.showZoomMenuFromCurrentEvent()
        } else {
            themeManager.zoomOut()
        }
    }

    private var palettePicker: some View {
        Picker(selection: $themeManager.activeThemeName) {
            ForEach(themeManager.themes) { theme in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: theme.colors.heading1) ?? .purple)
                        .frame(width: 10, height: 10)
                    Text(theme.name)
                }
                .tag(theme.name)
            }
        } label: {
            Label("Theme", systemImage: "paintpalette")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var editorButton: some View {
        let validEditors = editorManager.editors.filter(\.exists)

        if editorManager.editors.isEmpty {
            Button {
            } label: {
                Label("Open in Editor", systemImage: "square.and.pencil")
            }
            .disabled(true)
            .help("Configure an external editor in Settings")
        } else if validEditors.count == 1 {
            Button {
                openInEditor(validEditors[0])
            } label: {
                Label("Open in \(validEditors[0].name)", systemImage: "square.and.pencil")
            }
            .help("Open in \(validEditors[0].name)")
        } else {
            Menu {
                ForEach(editorManager.editors) { editor in
                    Button {
                        openInEditor(editor)
                    } label: {
                        HStack {
                            Text(editor.name)
                            if editor.opensFolder {
                                Text("(folder)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                Label("Open in Editor", systemImage: "square.and.pencil")
            }
            .help("Open in external editor")
        }
    }

    private func openInEditor(_ editor: EditorConfig) {
        guard let fileURL else { return }

        guard editor.exists else {
            missingEditorName = editor.name
            showMissingEditorAlert = true
            return
        }

        editorManager.openFile(fileURL, with: editor)
    }
}

final class ZoomToolbarConfigurator: NSObject {
    static let shared = ZoomToolbarConfigurator()

    private weak var themeManager: ThemeManager?
    private weak var observedToolbar: NSToolbar?

    func configure(in window: NSWindow, themeManager: ThemeManager) {
        self.themeManager = themeManager
        if let toolbar = window.toolbar {
            observeToolbar(toolbar)
            configureToolbar(toolbar)
        }
        configure(in: window, after: 0)
        configure(in: window, after: 0.1)
        configure(in: window, after: 0.5)
    }

    private func configure(in window: NSWindow, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
            guard let self, let window else { return }
            self.configureToolbar(in: window)
        }
    }

    private func configureToolbar(in window: NSWindow) {
        guard let toolbar = window.toolbar else { return }
        observeToolbar(toolbar)
        configureToolbar(toolbar)
    }

    private func configureToolbar(_ toolbar: NSToolbar) {
        for item in toolbar.items where isZoomToolbarItem(item) {
            configureZoomItem(item)
        }
    }

    private func observeToolbar(_ toolbar: NSToolbar) {
        guard observedToolbar !== toolbar else { return }

        if let observedToolbar {
            NotificationCenter.default.removeObserver(self, name: NSToolbar.willAddItemNotification, object: observedToolbar)
            NotificationCenter.default.removeObserver(self, name: NSToolbar.didRemoveItemNotification, object: observedToolbar)
        }

        observedToolbar = toolbar
        NotificationCenter.default.addObserver(self, selector: #selector(toolbarWillAddItem(_:)), name: NSToolbar.willAddItemNotification, object: toolbar)
        NotificationCenter.default.addObserver(self, selector: #selector(toolbarDidRemoveItem(_:)), name: NSToolbar.didRemoveItemNotification, object: toolbar)
    }

    @objc private func toolbarWillAddItem(_ notification: Notification) {
        if let item = notification.userInfo?[NSToolbarUserInfoKey.itemKey] as? NSToolbarItem,
           isZoomToolbarItem(item) {
            configureZoomItem(item)
        }
        scheduleConfigureToolbar(for: notification)
    }

    @objc private func toolbarDidRemoveItem(_ notification: Notification) {
        scheduleConfigureToolbar(for: notification)
    }

    private func scheduleConfigureToolbar(for notification: Notification) {
        guard let toolbar = notification.object as? NSToolbar else { return }
        DispatchQueue.main.async { [weak self, weak toolbar] in
            guard let self, let toolbar else { return }
            self.configureToolbar(toolbar)
        }
    }

    private func isZoomToolbarItem(_ item: NSToolbarItem) -> Bool {
        item.label == "Zoom"
            || item.label == "Zoom Out"
            || item.paletteLabel == "Zoom"
            || item.paletteLabel == "Zoom Out"
            || item.toolTip == "Zoom"
            || item.view?.accessibilityLabel() == "Zoom"
            || item.view.map(viewContainsZoomControls) == true
    }

    private func viewContainsZoomControls(_ view: NSView) -> Bool {
        if view.accessibilityLabel() == "Zoom"
            || view.accessibilityLabel() == "Zoom Out"
            || view.accessibilityHelp() == "Zoom"
            || view.accessibilityHelp() == "Zoom Out"
            || view.accessibilityIdentifier() == "minus.magnifyingglass"
            || view.accessibilityIdentifier() == "plus.magnifyingglass" {
            return true
        }

        for subview in view.subviews where viewContainsZoomControls(subview) {
            return true
        }
        return false
    }

    private func configureZoomItem(_ item: NSToolbarItem) {
        item.label = "Zoom"
        item.paletteLabel = "Zoom"
        item.toolTip = "Zoom"
        item.view = zoomControlView()
        item.label = "Zoom"
        item.paletteLabel = "Zoom"
        item.toolTip = "Zoom"
        item.target = self
        item.action = #selector(showZoomMenu(_:))
        item.menuFormRepresentation = zoomMenuItem()
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

    func showZoomMenuFromCurrentEvent() {
        showZoomMenu(nil)
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

    @objc private func showZoomMenu(_ sender: Any?) {
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
