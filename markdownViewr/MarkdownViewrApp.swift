import SwiftUI

@main
struct MarkdownViewrApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var editorManager = EditorManager()

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(
                document: file.$document,
                fileURL: file.fileURL
            )
            .environmentObject(themeManager)
            .environmentObject(editorManager)
        }
        .commands {
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
