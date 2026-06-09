import XCTest
@testable import markdownViewr

final class ThemeMigrationTests: XCTestCase {

    // MARK: - Decoding

    func testDecodesCurrentVersionTheme() throws {
        let json = minimalThemeJSON(schemaVersion: Theme.currentSchemaVersion)
        let theme = try JSONDecoder().decode(Theme.self, from: json)
        XCTAssertEqual(theme.schemaVersion, Theme.currentSchemaVersion)
    }

    func testMissingSchemaVersionDefaultsToOne() throws {
        // Themes written before versioning was added have no schemaVersion field.
        let json = minimalThemeJSON(schemaVersion: nil)
        let theme = try JSONDecoder().decode(Theme.self, from: json)
        XCTAssertEqual(theme.schemaVersion, 1)
    }

    func testUnknownFieldsAreIgnored() throws {
        // A theme from a future app version may have fields this version doesn't know about.
        // Decoding should succeed — unknown keys are silently ignored by Codable.
        var dict = minimalThemeDict(schemaVersion: Theme.currentSchemaVersion + 1)
        dict["futureField"] = "someValue"
        let json = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertNoThrow(try JSONDecoder().decode(Theme.self, from: json))
    }

    // MARK: - Migration

    func testMigrateNoOpAtCurrentVersion() throws {
        var theme = Theme(name: "Test")
        XCTAssertEqual(theme.schemaVersion, Theme.currentSchemaVersion)
        let manager = ThemeManager()
        let versionBefore = theme.schemaVersion
        manager.migrateIfNeeded(&theme)
        XCTAssertEqual(theme.schemaVersion, versionBefore, "migrateIfNeeded should not change version for a current-version theme")
    }

    func testNewThemeWrittenAtCurrentSchemaVersion() {
        let theme = Theme(name: "Fresh")
        XCTAssertEqual(theme.schemaVersion, Theme.currentSchemaVersion)
    }

    // MARK: - Round-trip

    func testEncodesSchemaVersion() throws {
        let theme = Theme(name: "RoundTrip")
        let data = try JSONEncoder().encode(theme)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encoded = try XCTUnwrap(dict["schemaVersion"] as? Int)
        XCTAssertEqual(encoded, Theme.currentSchemaVersion)
    }

    func testRoundTripPreservesAllFields() throws {
        let original = Theme(
            name: "Round Trip",
            colors: ThemeColors(background: "#ff0000", text: "#00ff00"),
            fonts: ThemeFonts(body: "Georgia", heading: "Helvetica", code: "Menlo"),
            sizes: ThemeSizes(baseFontSize: 16, lineHeight: 1.8),
            customCSS: "body { margin: 0; }"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Theme.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.schemaVersion, original.schemaVersion)
        XCTAssertEqual(decoded.colors.background, original.colors.background)
        XCTAssertEqual(decoded.colors.text, original.colors.text)
        XCTAssertEqual(decoded.fonts.body, original.fonts.body)
        XCTAssertEqual(decoded.sizes.baseFontSize, original.sizes.baseFontSize)
        XCTAssertEqual(decoded.sizes.lineHeight, original.sizes.lineHeight)
        XCTAssertEqual(decoded.customCSS, original.customCSS)
    }

    // MARK: - Helpers

    private func minimalThemeJSON(schemaVersion: Int?) -> Data {
        let dict = minimalThemeDict(schemaVersion: schemaVersion)
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private func minimalThemeDict(schemaVersion: Int?) -> [String: Any] {
        var dict: [String: Any] = [
            "name": "Minimal",
            "colors": [
                "background": "#000000", "text": "#ffffff",
                "heading1": "#ffffff", "heading2": "#ffffff",
                "heading3": "#ffffff", "heading4": "#ffffff",
                "heading5": "#ffffff", "heading6": "#ffffff",
                "link": "#0000ff", "codeBackground": "#111111",
                "codeText": "#ffffff", "blockquoteBorder": "#888888",
                "blockquoteBackground": "#222222",
                "highlightBackground": "#ffff00", "highlightText": "#000000"
            ],
            "fonts": ["body": "System", "heading": "System", "code": "SF Mono"],
            "sizes": [
                "baseFontSize": 14, "h1Size": 28, "h2Size": 23, "h3Size": 20,
                "h4Size": 18, "h5Size": 16, "h6Size": 15,
                "codeFontSize": 13, "lineHeight": 1.7
            ],
            "customCSS": ""
        ]
        if let v = schemaVersion {
            dict["schemaVersion"] = v
        }
        return dict
    }
}
