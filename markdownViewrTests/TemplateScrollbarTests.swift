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
