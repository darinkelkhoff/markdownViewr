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
    @AppStorage("tocVisible") private var tocVisible = false
    @AppStorage("tocDepth") private var tocDepth = 3
    @AppStorage("rawVisible") private var rawVisible = false

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
        .defaultSize(width: 700, height: 900)
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

            CommandGroup(replacing: .toolbar) {
                Toggle("Table of Contents", isOn: $tocVisible)
                    .keyboardShortcut("t", modifiers: .command)

                Menu("Table of Contents Depth") {
                    ForEach(1...6, id: \.self) { depth in
                        Button {
                            tocDepth = depth
                        } label: {
                            if tocDepth == depth {
                                Label("H\(depth)", systemImage: "checkmark")
                            } else {
                                Text("H\(depth)")
                            }
                        }
                    }
                }

                Toggle("Markdown Source", isOn: $rawVisible)
                    .keyboardShortcut("u", modifiers: .command)

                Divider()

                Button("Zoom In") {
                    themeManager.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    themeManager.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    themeManager.zoomReset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandMenu("Theme") {
                Button("Next Theme") {
                    themeManager.cycleTheme(direction: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])

                Button("Previous Theme") {
                    themeManager.cycleTheme(direction: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            }
        }
    }
}

struct DocumentWindowConfigurator: NSViewRepresentable {
    let fileURL: URL?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, let fileURL else { return }
            let autosaveName = "doc-\(fileURL.path.hashValue)"
            if !window.setFrameAutosaveName(autosaveName) {
                window.setFrameUsingName(autosaveName)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
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
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 600)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
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
