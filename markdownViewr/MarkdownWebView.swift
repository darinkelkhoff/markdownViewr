import SwiftUI
import WebKit
import Combine

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let themeCSS: String
    var fileURL: URL?
    var findBar: FindBarController?
    var tocVisible: Bool = false
    var tocDepth: Int = 3
    var tocWidth: Double = 220
    var tocWrap: Bool = false
    var tocBullets: Bool = false
    var rawSource: String = ""
    var rawVisible: Bool = false
    var rawWidth: Double = 400
    var onTocWidthChange: ((Double) -> Void)?
    var onRawWidthChange: ((Double) -> Void)?

    static func jsTemplateEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "vim")
        userContent.add(context.coordinator, name: "tocWidth")
        userContent.add(context.coordinator, name: "rawWidth")
        config.userContentController = userContent
        context.coordinator.onTocWidthChange = onTocWidthChange
        context.coordinator.onRawWidthChange = onRawWidthChange

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        loadContent(in: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTocWidthChange = onTocWidthChange
        context.coordinator.onRawWidthChange = onRawWidthChange
        if context.coordinator.lastHTML != html {
            let previousHTML = context.coordinator.lastHTML
            context.coordinator.lastHTML = html
            context.coordinator.lastCSS = themeCSS

            if previousHTML.isEmpty {
                loadContent(in: webView, context: context)
            } else {
                updateContent(in: webView)
            }
        } else if context.coordinator.lastCSS != themeCSS {
            context.coordinator.lastCSS = themeCSS
            injectCSS(in: webView)
        }

        if !context.coordinator.isPageLoaded {
            queueInitialState(context: context)
            return
        }

        if context.coordinator.lastTocVisible != tocVisible {
            context.coordinator.lastTocVisible = tocVisible
            webView.evaluateJavaScript("setTOCVisible(\(tocVisible))") { _, _ in }
        }
        if context.coordinator.lastTocDepth != tocDepth {
            context.coordinator.lastTocDepth = tocDepth
            webView.evaluateJavaScript("setTOCDepth(\(tocDepth))") { _, _ in }
        }
        if context.coordinator.lastTocWidth != tocWidth {
            context.coordinator.lastTocWidth = tocWidth
            webView.evaluateJavaScript("setTOCWidth(\(tocWidth))") { _, _ in }
        }
        if context.coordinator.lastTocWrap != tocWrap {
            context.coordinator.lastTocWrap = tocWrap
            webView.evaluateJavaScript("setTOCWrap(\(tocWrap))") { _, _ in }
        }
        if context.coordinator.lastTocBullets != tocBullets {
            context.coordinator.lastTocBullets = tocBullets
            webView.evaluateJavaScript("setTOCBullets(\(tocBullets))") { _, _ in }
        }
        if context.coordinator.lastRawSource != rawSource {
            context.coordinator.lastRawSource = rawSource
            webView.evaluateJavaScript("setRawSource(`\(Self.jsTemplateEscape(rawSource))`)") { _, _ in }
        }
        if context.coordinator.lastRawWidth != rawWidth {
            context.coordinator.lastRawWidth = rawWidth
            webView.evaluateJavaScript("setRawWidth(\(rawWidth))") { _, _ in }
        }
        if context.coordinator.lastRawVisible != rawVisible {
            context.coordinator.lastRawVisible = rawVisible
            webView.evaluateJavaScript("setRawVisible(\(rawVisible))") { _, _ in }
        }
    }

    private static let previewDirectory: URL = {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownViewr-previews")
        return tmp
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(findBar: findBar)
    }

    private func loadContent(in webView: WKWebView, context: Context) {
        guard let templateURL = Bundle.main.url(forResource: "template", withExtension: "html"),
              var template = try? String(contentsOf: templateURL, encoding: .utf8)
        else {
            webView.loadHTMLString("<p>Failed to load template</p>", baseURL: nil)
            return
        }

        context.coordinator.lastHTML = html
        context.coordinator.lastCSS = themeCSS
        context.coordinator.isPageLoaded = false
        #if MAS_BUILD
        // Images are inlined as data: URLs; a base href to the (sandboxed) folder is
        // both unreadable and unnecessary.
        template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "")
        #else
        if let fileDir = fileURL?.deletingLastPathComponent() {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "<base href=\"\(fileDir.absoluteString)\">")
        } else {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "")
        }
        #endif
        template = template.replacingOccurrences(of: "{{THEME_CSS}}", with: themeCSS)
        template = template.replacingOccurrences(of: "{{CONTENT}}", with: html)

        if fileURL != nil {
            let tempDir = Self.previewDirectory
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempHTML = tempDir.appendingPathComponent(UUID().uuidString + ".html")
            try? template.write(to: tempHTML, atomically: true, encoding: .utf8)
            #if MAS_BUILD
            // Self-contained HTML (images inlined); only the container temp dir is needed.
            webView.loadFileURL(tempHTML, allowingReadAccessTo: tempDir)
            #else
            // Grant read access to "/" so both the temp file and the document's images are accessible
            webView.loadFileURL(tempHTML, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            #endif
            context.coordinator.tempFileURL = tempHTML
        } else {
            webView.loadHTMLString(template, baseURL: nil)
        }

        // Queue document state to apply after page loads.
        queueInitialState(context: context)
    }

    private func queueInitialState(context: Context) {
        context.coordinator.pendingTocVisible = tocVisible
        context.coordinator.pendingTocDepth = tocDepth
        context.coordinator.pendingTocWidth = tocWidth
        context.coordinator.pendingTocWrap = tocWrap
        context.coordinator.pendingTocBullets = tocBullets
        context.coordinator.pendingRawSource = rawSource
        context.coordinator.pendingRawWidth = rawWidth
        context.coordinator.pendingRawVisible = rawVisible
    }

    private func updateContent(in webView: WKWebView) {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = "updateContent(`\(escaped)`);"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                print("Content update error: \(error)")
            }
        }
    }

    private func injectCSS(in webView: WKWebView) {
        let escapedCSS = themeCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        webView.evaluateJavaScript("updateThemeCSS('\(escapedCSS)')") { _, error in
            if let error {
                print("Theme update error: \(error)")
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var lastHTML: String = ""
        var lastCSS: String = ""
        var lastTocVisible: Bool = false
        var lastTocDepth: Int = 3
        var lastTocWidth: Double = 220
        var lastTocWrap: Bool = false
        var lastTocBullets: Bool = false
        var lastRawSource: String = ""
        var lastRawVisible: Bool = false
        var lastRawWidth: Double = 400
        var isPageLoaded = false
        var pendingTocVisible: Bool?
        var pendingTocDepth: Int?
        var pendingTocWidth: Double?
        var pendingTocWrap: Bool?
        var pendingTocBullets: Bool?
        var pendingRawSource: String?
        var pendingRawVisible: Bool?
        var pendingRawWidth: Double?
        var onTocWidthChange: ((Double) -> Void)?
        var onRawWidthChange: ((Double) -> Void)?
        var tempFileURL: URL?
        private var findBarObservation: Any?
        private var lastSearchText: String = ""

        weak var findBar: FindBarController?

        init(findBar: FindBarController?) {
            self.findBar = findBar
            super.init()
            guard let findBar else { return }

            findBar.onFindNext = { [weak self] in
                self?.findNext()
            }
            findBar.onFindPrevious = { [weak self] in
                self?.findPrevious()
            }

            findBarObservation = findBar.$searchText
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .sink { [weak self] text in
                    guard let self else { return }
                    if text.isEmpty {
                        self.clearFind()
                    } else {
                        self.lastSearchText = text
                        self.findAll(text)
                    }
                }
        }

        private func findAll(_ text: String) {
            guard let webView else { return }
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("findAll('\(escaped)')") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func findNext() {
            guard let webView else { return }
            webView.evaluateJavaScript("findNext()") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func findPrevious() {
            guard let webView else { return }
            webView.evaluateJavaScript("findPrev()") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func clearFind() {
            guard let webView else { return }
            webView.evaluateJavaScript("clearFind()") { _, _ in }
            DispatchQueue.main.async { [weak self] in
                self?.findBar?.matchStatus = nil
            }
        }

        private func updateFindStatus(_ result: Any?) {
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let status = try? JSONDecoder().decode(FindStatus.self, from: data)
            else { return }
            DispatchQueue.main.async { [weak self] in
                self?.findBar?.matchStatus = status
            }
        }

        deinit {
            if let url = tempFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "tocWidth" {
                guard let width = (message.body as? NSNumber)?.doubleValue else { return }
                lastTocWidth = width
                DispatchQueue.main.async { [weak self] in
                    self?.onTocWidthChange?(width)
                }
                return
            }
            if message.name == "rawWidth" {
                guard let width = (message.body as? NSNumber)?.doubleValue else { return }
                lastRawWidth = width
                DispatchQueue.main.async { [weak self] in
                    self?.onRawWidthChange?(width)
                }
                return
            }
            guard message.name == "vim", let action = message.body as? String else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch action {
                case "focusFind": self.findBar?.show()
                case "findNext": self.findNext()
                case "findPrev": self.findPrevious()
                default: break
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            if let width = pendingTocWidth {
                lastTocWidth = width
                webView.evaluateJavaScript("setTOCWidth(\(width))") { _, _ in }
                pendingTocWidth = nil
            }
            if let wrap = pendingTocWrap {
                lastTocWrap = wrap
                webView.evaluateJavaScript("setTOCWrap(\(wrap))") { _, _ in }
                pendingTocWrap = nil
            }
            if let bullets = pendingTocBullets {
                lastTocBullets = bullets
                webView.evaluateJavaScript("setTOCBullets(\(bullets))") { _, _ in }
                pendingTocBullets = nil
            }
            if let visible = pendingTocVisible {
                lastTocVisible = visible
                webView.evaluateJavaScript("setTOCVisible(\(visible))") { _, _ in }
                pendingTocVisible = nil
            }
            if let depth = pendingTocDepth {
                lastTocDepth = depth
                webView.evaluateJavaScript("setTOCDepth(\(depth))") { _, _ in }
                pendingTocDepth = nil
            }
            if let source = pendingRawSource {
                lastRawSource = source
                webView.evaluateJavaScript("setRawSource(`\(MarkdownWebView.jsTemplateEscape(source))`)") { _, _ in }
                pendingRawSource = nil
            }
            if let width = pendingRawWidth {
                lastRawWidth = width
                webView.evaluateJavaScript("setRawWidth(\(width))") { _, _ in }
                pendingRawWidth = nil
            }
            if let visible = pendingRawVisible {
                lastRawVisible = visible
                webView.evaluateJavaScript("setRawVisible(\(visible))") { _, _ in }
                pendingRawVisible = nil
            }
            // Initial TOC state is set; re-enable transitions so toggles animate.
            webView.evaluateJavaScript("enableTOCTransitions()") { _, _ in }
        }
    }
}
