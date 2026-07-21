import SwiftUI
#if !MAS_BUILD
import Sparkle
#endif

@main
struct MarkdownViewrApp: App {
    @NSApplicationDelegateAdaptor(FileMenuPrunerApplicationDelegate.self) private var appDelegate

    #if !MAS_BUILD
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var editorManager: EditorManager
    @FocusedValue(\.documentViewCommands) private var documentViewCommands

    init() {
        let editorManager = EditorManager()
        _editorManager = StateObject(wrappedValue: editorManager)
        ExternalEditorFileMenuController.shared.editorManager = editorManager
    }

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(
                document: file.$document,
                fileURL: file.fileURL
            )
            .environmentObject(themeManager)
            .environmentObject(editorManager)
            .background(DocumentWindowConfigurator(fileURL: file.fileURL))
        }
        .defaultSize(width: 1100, height: 800)
        .commands {
            #if !MAS_BUILD
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
            }
            #endif

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.shared.show(
                        themeManager: themeManager,
                        editorManager: editorManager
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    documentViewCommands?.printDocument()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(documentViewCommands == nil)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    NotificationCenter.default.post(name: .findToggle, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("markdownViewr Help") {
                    HelpWindowController.shared.show()
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            CommandGroup(before: .toolbar) {
                DocumentViewCommandItems()
            }

            CommandMenu("Theme") {
                Button("Next Theme") {
                    documentViewCommands?.nextTheme()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
                .disabled(documentViewCommands == nil)

                Button("Previous Theme") {
                    documentViewCommands?.previousTheme()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
                .disabled(documentViewCommands == nil)
            }
        }
    }
}

struct DocumentViewCommandItems: View {
    @FocusedValue(\.documentViewCommands) private var documentViewCommands

    var body: some View {
        Toggle("Table of Contents", isOn: documentViewCommands?.tocVisible ?? .constant(false))
            .keyboardShortcut("t", modifiers: .command)
            .disabled(documentViewCommands == nil)

        Menu("Table of Contents Depth") {
            ForEach(1...6, id: \.self) { depth in
                Button {
                    documentViewCommands?.setTocDepth(depth)
                } label: {
                    if documentViewCommands?.tocDepth == depth {
                        Label("H\(depth)", systemImage: "checkmark")
                    } else {
                        Text("H\(depth)")
                    }
                }
            }
        }
        .disabled(documentViewCommands == nil)

        Toggle("Markdown Source", isOn: documentViewCommands?.rawVisible ?? .constant(false))
            .keyboardShortcut("u", modifiers: .command)
            .disabled(documentViewCommands == nil)

        Divider()

        Button("Zoom In") {
            documentViewCommands?.zoomIn()
        }
        .keyboardShortcut("+", modifiers: .command)
        .disabled(documentViewCommands == nil)

        Button("Zoom Out") {
            documentViewCommands?.zoomOut()
        }
        .keyboardShortcut("-", modifiers: .command)
        .disabled(documentViewCommands == nil)

        Button("Actual Size") {
            documentViewCommands?.zoomReset()
        }
        .keyboardShortcut("0", modifiers: .command)
        .disabled(documentViewCommands == nil)
    }
}

struct DocumentWindowConfigurator: NSViewRepresentable {
    let fileURL: URL?
    @AppStorage("defaultTocVisible") private var defaultTocVisible = false
    @AppStorage("defaultRawVisible") private var defaultRawVisible = false

    static func defaultDocumentWindowSize(tocVisible: Bool, rawVisible: Bool) -> NSSize {
        let width: CGFloat
        switch (tocVisible, rawVisible) {
        case (true, true):
            width = 1500
        case (false, true):
            width = 1350
        case (true, false):
            width = 1250
        case (false, false):
            width = 1100
        }
        return NSSize(width: width, height: 800)
    }

    static func shouldApplyDocumentFrame(isTabbedWindow: Bool) -> Bool {
        !isTabbedWindow
    }

    static func autosaveName(for fileURL: URL) -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-_.")
        let stablePath = fileURL.standardizedFileURL.path
        let encodedPath = stablePath.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? stablePath
        return "doc-\(encodedPath)"
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view, context: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configureWindow(for view: NSView, context: Context) {
        guard let window = view.window, let fileURL else { return }
        let autosaveName = Self.autosaveName(for: fileURL)
        guard context.coordinator.needsConfiguration(for: window, autosaveName: autosaveName) else { return }

        if Self.shouldApplyDocumentFrame(isTabbedWindow: Self.isTabbedWindow(window)) {
            let restoredFrame = window.setFrameUsingName(autosaveName)
            if !restoredFrame {
                window.setContentSize(Self.defaultDocumentWindowSize(tocVisible: defaultTocVisible, rawVisible: defaultRawVisible))
                window.center()
            }
        }
        window.setFrameAutosaveName(autosaveName)
        context.coordinator.configureSavingFrame(for: window, autosaveName: autosaveName)
    }

    private static func isTabbedWindow(_ window: NSWindow) -> Bool {
        window.tabbedWindows?.contains { $0 !== window } == true
    }

    class Coordinator {
        private weak var configuredWindow: NSWindow?
        private var configuredAutosaveName: String?
        private var observerTokens: [NSObjectProtocol] = []

        func needsConfiguration(for window: NSWindow, autosaveName: String) -> Bool {
            configuredWindow !== window || configuredAutosaveName != autosaveName
        }

        func configureSavingFrame(for window: NSWindow, autosaveName: String) {
            removeObservers()
            configuredWindow = window
            configuredAutosaveName = autosaveName

            let center = NotificationCenter.default
            let saveFrame: (Notification) -> Void = { [weak window] _ in
                window?.saveFrame(usingName: autosaveName)
            }
            observerTokens = [
                center.addObserver(
                    forName: NSWindow.willCloseNotification,
                    object: window,
                    queue: .main,
                    using: saveFrame
                ),
                center.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main,
                    using: saveFrame
                ),
                center.addObserver(
                    forName: NSWindow.didMoveNotification,
                    object: window,
                    queue: .main,
                    using: saveFrame
                )
            ]
            window.saveFrame(usingName: autosaveName)
        }

        deinit {
            removeObservers()
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            observerTokens.forEach { center.removeObserver($0) }
            observerTokens = []
        }
    }
}

class HelpWindowController: NSObject, NSWindowDelegate {
    static let shared = HelpWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: HelpView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 620, height: 540)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "markdownViewr Help"
        window.contentView = hostingView
        window.minSize = NSSize(width: 460, height: 340)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(themeManager: ThemeManager, editorManager: EditorManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(themeManager)
            .environmentObject(editorManager)

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 720)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "markdownViewr Settings"
        window.contentView = hostingView
        window.minSize = NSSize(width: 380, height: 350)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
