import XCTest
@testable import markdownViewr

final class ImageInlinerTests: XCTestCase {
    func testInlinesRelativeImageAsDataURL() {
        let html = "<p><img src=\"img/a.png\" alt=\"x\"></p>"
        let bytes = Data([0x01, 0x02, 0x03])
        let out = ImageInliner.inlineLocalImages(in: html) { path in
            path == "img/a.png" ? bytes : nil
        }
        XCTAssertTrue(out.contains("data:image/png;base64,\(bytes.base64EncodedString())"))
        XCTAssertFalse(out.contains("img/a.png"))
        XCTAssertTrue(out.contains("alt=\"x\""))
    }

    func testLeavesRemoteImageUntouched() {
        let html = "<img src=\"https://example.com/a.png\">"
        let out = ImageInliner.inlineLocalImages(in: html) { _ in Data([0]) }
        XCTAssertEqual(out, html)
    }

    func testLeavesAbsolutePathUntouched() {
        let html = "<img src=\"/Users/x/a.png\">"
        let out = ImageInliner.inlineLocalImages(in: html) { _ in Data([0]) }
        XCTAssertEqual(out, html)
    }

    func testLeavesUnresolvableRelativeImageUntouched() {
        let html = "<img src=\"missing.png\">"
        let out = ImageInliner.inlineLocalImages(in: html) { _ in nil }
        XCTAssertEqual(out, html)
    }

    func testContainsLocalImageTrueForRelativeSrc() {
        XCTAssertTrue(ImageInliner.containsLocalImage(in: "<img src=\"images/a.png\">"))
    }

    func testContainsLocalImageFalseForRemoteOnly() {
        XCTAssertFalse(ImageInliner.containsLocalImage(in: "<img src=\"https://example.com/a.png\">"))
    }

    func testContainsLocalImageFalseForNoImages() {
        XCTAssertFalse(ImageInliner.containsLocalImage(in: "<p>no images here</p>"))
    }

    func testContainsLocalImageFalseForAbsolutePath() {
        XCTAssertFalse(ImageInliner.containsLocalImage(in: "<img src=\"/Users/x/a.png\">"))
    }

    func testDecodesPercentEncodedPathBeforeResolving() {
        let html = "<img src=\"my%20pic.png\">"
        let bytes = Data([0xAA])
        let out = ImageInliner.inlineLocalImages(in: html) { path in
            path == "my pic.png" ? bytes : nil
        }
        XCTAssertTrue(out.contains("data:image/png;base64,\(bytes.base64EncodedString())"))
    }
}
