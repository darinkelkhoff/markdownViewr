import SwiftUI

struct WindowResizer: NSViewRepresentable {
    var minSize: NSSize?

    func makeNSView(context: Context) -> NSView {
        let view = WindowResizerView(minSize: minSize)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class WindowResizerView: NSView {
    let minSize: NSSize?
    private var observation: NSKeyValueObservation?

    init(minSize: NSSize?) {
        self.minSize = minSize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            observation = nil
            return
        }

        configureWindow(window)

        // SwiftUI may reset the style mask after initial setup,
        // so observe it and re-apply resizable whenever it changes.
        observation = window.observe(\.styleMask, options: [.new]) { [weak self] window, _ in
            guard let self else { return }
            if !window.styleMask.contains(.resizable) {
                DispatchQueue.main.async {
                    self.configureWindow(window)
                }
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        window.styleMask.insert(.resizable)
        if let minSize {
            window.minSize = minSize
        }
    }
}
