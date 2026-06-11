# Mac App Store Dual-Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a sandboxed Mac App Store build variant alongside the existing Developer ID build, from one codebase, with all sandbox-specific behavior isolated behind a `MAS_BUILD` compile flag.

**Architecture:** A second pair of XcodeGen build configurations (`Debug-MAS`, `Release-MAS`) flips on the sandbox via an entitlements file and defines `MAS_BUILD`. Sparkle is compiled out of the MAS binary. A `FolderAccessManager` acquires a persisted security-scoped bookmark to the document's folder (powering both file-watching and image reads), and local images are inlined as `data:` URLs so the sandboxed WKWebView never needs broad file access. The Developer ID build is unchanged at runtime.

**Tech Stack:** Swift, SwiftUI, AppKit (NSOpenPanel, security-scoped bookmarks), WKWebView, XcodeGen, xcodebuild.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `project.yml` | Add `configs` map; per-config sandbox/entitlements/flags; move Sparkle Info.plist keys to non-MAS configs | Modify |
| `markdownViewr/markdownViewr-MAS.entitlements` | Sandbox entitlements for the MAS build | Create |
| `markdownViewr/MarkdownViewrApp.swift` | Guard Sparkle behind `#if !MAS_BUILD` | Modify |
| `markdownViewr/HelpView.swift` | Don't advertise Sparkle updates in MAS build | Modify |
| `markdownViewr/ImageInliner.swift` | Pure helper: rewrite `<img>` local `src` to `data:` URLs | Create |
| `markdownViewrTests/ImageInlinerTests.swift` | Unit tests for the inliner | Create |
| `markdownViewr/FolderAccessManager.swift` | Acquire/persist/hold security-scoped folder access; resolve image bytes | Create |
| `markdownViewr/ContentView.swift` | Gate watching on access; show grant banner; inline images on render | Modify |
| `markdownViewr/MarkdownWebView.swift` | MAS: scope read-access to temp dir, no base tag | Modify |
| `ExportOptions-MAS.plist` | App Store export options | Create |
| `justfile` | `release-mas` recipe | Modify |

**Test runner (per user convention):** All tests run via `/tmp/markdownViewr-claude-run-tests.sh` (created in Task 3), which writes output to `/tmp/markdownViewr-claude-test-output.txt`. Builds are run inline with `xcodebuild`.

---

## Task 1: MAS build configurations + entitlements

**Files:**
- Modify: `project.yml`
- Create: `markdownViewr/markdownViewr-MAS.entitlements`

- [ ] **Step 1: Create the MAS entitlements file**

Create `markdownViewr/markdownViewr-MAS.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Add the `configs` map to `project.yml`**

At the top level of `project.yml` (e.g. directly after the `options:` block), add:

```yaml
configs:
  Debug: debug
  Release: release
  Debug-MAS: debug
  Release-MAS: release
```

- [ ] **Step 3: Remove the always-non-sandboxed base setting and the Sparkle Info.plist keys**

In `project.yml`, in the `markdownViewr` target's `settings.base`, DELETE this line (sandbox is now controlled per-config via the entitlements file):

```yaml
        ENABLE_APP_SANDBOX: "NO"
```

In the `markdownViewr` target's `info.properties`, DELETE these two lines (they will be re-injected for non-MAS configs only in the next step):

```yaml
        SUFeedURL: "https://raw.githubusercontent.com/darinkelkhoff/markdownViewr/main/appcast.xml"
        SUPublicEDKey: "flXZnzfoR5H/JgMTtAGza8SUcUbfK4FWUPEBjxkSZyc="
```

- [ ] **Step 4: Add per-config settings to the `markdownViewr` target**

In `project.yml`, under the `markdownViewr` target's `settings:` (which currently only has `base:`), add a `configs:` sibling so it reads:

```yaml
    settings:
      base:
        INFOPLIST_FILE: markdownViewr/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.dkelkhoff.markdownViewr
        MARKETING_VERSION: "1.2.0"
        CURRENT_PROJECT_VERSION: "3"
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      configs:
        Debug:
          INFOPLIST_KEY_SUFeedURL: "https://raw.githubusercontent.com/darinkelkhoff/markdownViewr/main/appcast.xml"
          INFOPLIST_KEY_SUPublicEDKey: "flXZnzfoR5H/JgMTtAGza8SUcUbfK4FWUPEBjxkSZyc="
        Release:
          INFOPLIST_KEY_SUFeedURL: "https://raw.githubusercontent.com/darinkelkhoff/markdownViewr/main/appcast.xml"
          INFOPLIST_KEY_SUPublicEDKey: "flXZnzfoR5H/JgMTtAGza8SUcUbfK4FWUPEBjxkSZyc="
        Debug-MAS:
          CODE_SIGN_ENTITLEMENTS: markdownViewr/markdownViewr-MAS.entitlements
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) MAS_BUILD"
        Release-MAS:
          CODE_SIGN_ENTITLEMENTS: markdownViewr/markdownViewr-MAS.entitlements
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) MAS_BUILD"
```

Note: `ENABLE_APP_SANDBOX` is intentionally NOT set — the entitlements file is the single source of truth for sandboxing, present only in the MAS configs.

- [ ] **Step 5: Regenerate and verify the configs exist**

Run: `xcodegen generate`
Then: `xcodebuild -project markdownViewr.xcodeproj -list`
Expected: the `Build Configurations:` list includes `Debug`, `Release`, `Debug-MAS`, and `Release-MAS`.

- [ ] **Step 6: Verify the Developer ID Info.plist still has Sparkle keys, MAS does not**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release -showBuildSettings 2>/dev/null | grep -i 'INFOPLIST_KEY_SUFeedURL'`
Expected: shows the appcast URL.

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release-MAS -showBuildSettings 2>/dev/null | grep -ci 'INFOPLIST_KEY_SUFeedURL'`
Expected: `0`

(If `INFOPLIST_KEY_`-prefixed custom keys do not appear in the built `Info.plist` on this Xcode version, fall back to two static Info.plist files: a shared `Info.plist` without Sparkle keys, plus `Info-DevID.plist` with them, and set `INFOPLIST_FILE` per-config. Verify by building and running `plutil -p` on the built app's `Contents/Info.plist`.)

- [ ] **Step 7: Build both variants to confirm the project is valid**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release build`
Expected: `BUILD SUCCEEDED`.

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS build`
Expected: `BUILD SUCCEEDED` (Sparkle still compiles here — it is removed in Task 2).

- [ ] **Step 8: Commit**

```bash
git add project.yml markdownViewr/markdownViewr-MAS.entitlements
git commit -m "build: add Mac App Store build configurations and entitlements"
```

---

## Task 2: Compile Sparkle out of the MAS build

**Files:**
- Modify: `markdownViewr/MarkdownViewrApp.swift:1-31`
- Modify: `markdownViewr/HelpView.swift:54`

- [ ] **Step 1: Guard the Sparkle import**

In `markdownViewr/MarkdownViewrApp.swift`, replace lines 1-2:

```swift
import SwiftUI
import Sparkle
```

with:

```swift
import SwiftUI
#if !MAS_BUILD
import Sparkle
#endif
```

- [ ] **Step 2: Guard the updater controller property**

In `markdownViewr/MarkdownViewrApp.swift`, wrap the `updaterController` property (currently lines 6-10):

```swift
    #if !MAS_BUILD
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif
```

- [ ] **Step 3: Guard the "Check for Updates" command**

In `markdownViewr/MarkdownViewrApp.swift`, wrap the entire `CommandGroup(after: .appInfo)` block (currently lines 26-31). `#if` is valid inside SwiftUI's `commands` result builder, so in the MAS build the menu item is never added to the menu:

```swift
            #if !MAS_BUILD
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
            }
            #endif
```

- [ ] **Step 4: Don't advertise Sparkle in the MAS build's Help**

Read `markdownViewr/HelpView.swift` around line 54 to see the exact surrounding string-array/list context. The line currently reads:

```swift
            - Automatic updates via Sparkle
```

Replace it so the bullet is conditional. If it is part of a multi-line Swift string literal, split the literal so only the non-MAS build includes the line, e.g.:

```swift
            #if !MAS_BUILD
            - Automatic updates via Sparkle
            #endif
```

If `#if` cannot be placed inside that specific literal/view construct, instead remove the Sparkle bullet from the shared text and append it only in the non-MAS build via the surrounding view/string-builder. The requirement: the MAS build's Help must not mention Sparkle or automatic updates.

- [ ] **Step 5: Build the MAS variant and confirm Sparkle is compiled out**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS build`
Expected: `BUILD SUCCEEDED` with no reference to `SPUStandardUpdaterController` (the symbol is inside `#if !MAS_BUILD`).

- [ ] **Step 6: Build the Developer ID variant and confirm it is unchanged**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release build`
Expected: `BUILD SUCCEEDED`; the "Check for Updates…" command and Sparkle updater still compile.

- [ ] **Step 7: Commit**

```bash
git add markdownViewr/MarkdownViewrApp.swift markdownViewr/HelpView.swift
git commit -m "build: compile Sparkle out of the Mac App Store build"
```

---

## Task 3: Image-inlining helper (pure, TDD)

**Files:**
- Create: `markdownViewr/ImageInliner.swift`
- Test: `markdownViewrTests/ImageInlinerTests.swift`
- Create: `/tmp/markdownViewr-claude-run-tests.sh`

- [ ] **Step 1: Create the test-runner script**

Write `/tmp/markdownViewr-claude-run-tests.sh` (the ONLY way tests are run; always invoked with zero arguments):

```bash
#!/usr/bin/env bash
set -o pipefail
cd /Users/dkelkhoff/git/personal/markdownViewr
xcodebuild test \
    -project markdownViewr.xcodeproj \
    -scheme markdownViewrTests \
    -destination 'platform=macOS' \
    > /tmp/markdownViewr-claude-test-output.txt 2>&1
echo "exit=$?" >> /tmp/markdownViewr-claude-test-output.txt
```

Then: `chmod +x /tmp/markdownViewr-claude-run-tests.sh`

- [ ] **Step 2: Write the failing tests**

Create `markdownViewrTests/ImageInlinerTests.swift`:

```swift
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

    func testDecodesPercentEncodedPathBeforeResolving() {
        let html = "<img src=\"my%20pic.png\">"
        let bytes = Data([0xAA])
        let out = ImageInliner.inlineLocalImages(in: html) { path in
            path == "my pic.png" ? bytes : nil
        }
        XCTAssertTrue(out.contains("data:image/png;base64,\(bytes.base64EncodedString())"))
    }
}
```

- [ ] **Step 3: Add the new files to the project and run the tests to verify they fail**

Run: `xcodegen generate`
Then: `/tmp/markdownViewr-claude-run-tests.sh`
Then read `/tmp/markdownViewr-claude-test-output.txt`.
Expected: compilation failure — `ImageInliner` is not defined yet.

- [ ] **Step 4: Implement the helper**

Create `markdownViewr/ImageInliner.swift`:

```swift
import Foundation

/// Rewrites `<img>` tags whose `src` is a local, relative path into self-contained
/// `data:` URLs, using a caller-supplied byte resolver. Remote (`http(s)`), `data:`,
/// and absolute-path sources are left untouched. Pure and synchronous so it is unit
/// testable without any filesystem or sandbox dependency.
enum ImageInliner {
    static func inlineLocalImages(in html: String, resolve: (String) -> Data?) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<img([^>]*?)src=\"([^\"]*)\"([^>]*)>",
            options: []
        ) else { return html }

        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return html }

        var result = ""
        var last = 0
        for match in matches {
            let full = match.range
            result += ns.substring(with: NSRange(location: last, length: full.location - last))

            let pre = ns.substring(with: match.range(at: 1))
            let src = ns.substring(with: match.range(at: 2))
            let post = ns.substring(with: match.range(at: 3))

            let decoded = src.removingPercentEncoding ?? src
            if isLocalRelative(src), let data = resolve(decoded) {
                let mime = mimeType(forExtension: (src as NSString).pathExtension)
                result += "<img\(pre)src=\"data:\(mime);base64,\(data.base64EncodedString())\"\(post)>"
            } else {
                result += ns.substring(with: full)
            }
            last = full.location + full.length
        }
        result += ns.substring(with: NSRange(location: last, length: ns.length - last))
        return result
    }

    static func isLocalRelative(_ src: String) -> Bool {
        if src.isEmpty { return false }
        if src.hasPrefix("data:") { return false }
        if src.contains("://") { return false }   // http://, https://, file://
        if src.hasPrefix("/") { return false }     // absolute path — unreadable under sandbox
        return true
    }

    static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "tif", "tiff": return "image/tiff"
        default: return "application/octet-stream"
        }
    }
}
```

- [ ] **Step 5: Add the file to the project and run the tests to verify they pass**

Run: `xcodegen generate`
Then: `/tmp/markdownViewr-claude-run-tests.sh`
Then read `/tmp/markdownViewr-claude-test-output.txt`.
Expected: `exit=0`, all `ImageInlinerTests` pass.

- [ ] **Step 6: Commit**

```bash
git add markdownViewr/ImageInliner.swift markdownViewrTests/ImageInlinerTests.swift
git commit -m "feat: add ImageInliner for sandbox-safe data-URL image embedding"
```

---

## Task 4: FolderAccessManager (security-scoped folder access)

**Files:**
- Create: `markdownViewr/FolderAccessManager.swift`

This type exists in BOTH builds with a uniform interface. In the non-MAS build it is a no-op that always reports access, so the `ContentView` body needs no `#if`. All sandbox/bookmark logic lives behind `#if MAS_BUILD` inside this file.

- [ ] **Step 1: Create the manager**

Create `markdownViewr/FolderAccessManager.swift`:

```swift
import Foundation
import AppKit

/// Owns access to the directory containing the currently-open document. In the MAS
/// (sandboxed) build it resolves or requests a persisted app-scoped security-scoped
/// bookmark for that folder and holds access for the manager's lifetime. In the
/// Developer ID build it is an inert pass-through that always reports access.
final class FolderAccessManager: ObservableObject {
    /// True when the document's folder is accessible (always true in the non-MAS build).
    @Published private(set) var hasAccess: Bool = false

    private var folderURL: URL?
    private var accessedURL: URL?

    deinit {
        accessedURL?.stopAccessingSecurityScopedResource()
    }

    /// Resolves any stored access for the document's folder. Call once when a document opens.
    func prepare(for fileURL: URL) {
        let folder = fileURL.deletingLastPathComponent()
        folderURL = folder
        #if MAS_BUILD
        guard let data = UserDefaults.standard.data(forKey: Self.key(for: folder)) else {
            hasAccess = false
            return
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ), url.startAccessingSecurityScopedResource() else {
            hasAccess = false
            return
        }
        accessedURL = url
        hasAccess = true
        if stale { storeBookmark(for: url) }
        #else
        hasAccess = true
        #endif
    }

    /// Presents a folder picker (MAS only) to obtain and persist access. Calls back on the main queue.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        #if MAS_BUILD
        guard let folder = folderURL else { completion(false); return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.prompt = "Allow Access"
        panel.message = "Allow markdownViewr to access this folder to show images and auto-reload changes."
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  url.startAccessingSecurityScopedResource() else {
                completion(false)
                return
            }
            self.accessedURL?.stopAccessingSecurityScopedResource()
            self.accessedURL = url
            self.storeBookmark(for: url)
            self.hasAccess = true
            completion(true)
        }
        #else
        completion(true)
        #endif
    }

    /// Reads bytes for a path relative to the document's folder, or nil if unavailable.
    /// Used by the MAS render path to inline images. Returns nil when access is not held.
    func imageData(forRelativePath path: String) -> Data? {
        guard hasAccess, let base = accessedURL ?? folderURL else { return nil }
        let url = base.appendingPathComponent(path)
        return try? Data(contentsOf: url)
    }

    #if MAS_BUILD
    private func storeBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        // Key by the document's folder so the same document re-grants silently next launch.
        if let folder = folderURL {
            UserDefaults.standard.set(data, forKey: Self.key(for: folder))
        }
        UserDefaults.standard.set(data, forKey: Self.key(for: url))
    }

    private static func key(for folder: URL) -> String {
        "folderBookmark:\(folder.standardizedFileURL.path)"
    }
    #endif
}
```

- [ ] **Step 2: Add the file and build both variants**

Run: `xcodegen generate`
Then: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release build`
Expected: `BUILD SUCCEEDED` (non-MAS: `hasAccess` defaults set in `prepare`, no bookmark code compiled).

Then: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add markdownViewr/FolderAccessManager.swift
git commit -m "feat: add FolderAccessManager for sandboxed folder access"
```

---

## Task 5: Wire folder access + grant banner into ContentView

**Files:**
- Modify: `markdownViewr/ContentView.swift:20-99`

- [ ] **Step 1: Add the access manager and a render helper**

In `markdownViewr/ContentView.swift`, add a `@StateObject` for the manager alongside the existing `@StateObject` declarations (after line 30):

```swift
    @StateObject private var folderAccess = FolderAccessManager()
```

- [ ] **Step 2: Make `rerender()` inline images in the MAS build**

Replace the existing `rerender()` (lines 39-45) with:

```swift
    private func rerender() {
        var html = MarkdownDocument.convertToHTML(
            currentMarkdown,
            frontmatterMode: themeManager.frontmatterMode,
            extensions: themeManager.markdownExtensions
        )
        #if MAS_BUILD
        if folderAccess.hasAccess {
            html = ImageInliner.inlineLocalImages(in: html) { path in
                folderAccess.imageData(forRelativePath: path)
            }
        }
        #endif
        renderedHTML = html
    }
```

- [ ] **Step 3: Add a helper to start watching once access is available**

Add this method to `ContentView` (next to `rerender()`):

```swift
    private func beginLiveContent() {
        guard let fileURL else { return }
        rerender()
        liveContent.startWatching(fileURL: fileURL)
    }
```

- [ ] **Step 4: Replace `onAppear` to gate watching on access**

Replace the existing `.onAppear { ... }` block (lines 82-88) with:

```swift
        .onAppear {
            liveContent.rawMarkdown = document.rawMarkdown
            rerender()
            if let fileURL {
                folderAccess.prepare(for: fileURL)
                if folderAccess.hasAccess {
                    beginLiveContent()
                }
            }
        }
```

In the Developer ID build `folderAccess.hasAccess` is always true after `prepare`, so this preserves today's behavior (watch immediately).

- [ ] **Step 5: Add the grant banner**

Wrap the `MarkdownWebView` in the `body`'s `VStack` so a banner can sit above it. Replace the `VStack(spacing: 0) { ... }` opening through the `MarkdownWebView(...)` call (lines 48-60) with:

```swift
        VStack(spacing: 0) {
            if findBar.isVisible {
                FindBarView(findBar: findBar)
            }
            if !folderAccess.hasAccess, fileURL != nil {
                FolderAccessBanner {
                    folderAccess.requestAccess { granted in
                        if granted { beginLiveContent() }
                    }
                }
            }
            MarkdownWebView(
                html: renderedHTML,
                themeCSS: themeManager.generateCSS(for: themeManager.activeTheme),
                fileURL: fileURL,
                findBar: findBar,
                tocVisible: tocVisible,
                tocDepth: tocDepth
            )
        }
```

Because `folderAccess.hasAccess` is always true in the non-MAS build, the banner never renders there — no `#if` needed in the view body.

- [ ] **Step 6: Define the banner view**

At the bottom of `markdownViewr/ContentView.swift` (file scope, after the `ContentView` struct), add:

```swift
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
```

- [ ] **Step 7: Build both variants**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release build`
Expected: `BUILD SUCCEEDED`.

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Run the unit tests to confirm no regression**

Run: `/tmp/markdownViewr-claude-run-tests.sh`
Then read `/tmp/markdownViewr-claude-test-output.txt`.
Expected: `exit=0`, all tests pass.

- [ ] **Step 9: Commit**

```bash
git add markdownViewr/ContentView.swift
git commit -m "feat: gate file-watching on folder access and add grant banner (MAS)"
```

---

## Task 6: Scope WKWebView read access for the sandbox

**Files:**
- Modify: `markdownViewr/MarkdownWebView.swift:65-98`

In the MAS build the preview HTML is self-contained (images already inlined by `rerender`), so the WebView only needs read access to the container temp dir, and the `<base href>` to the user's folder (unreadable under sandbox) must be omitted.

- [ ] **Step 1: Make the base tag and read-access scope build-specific**

In `markdownViewr/MarkdownWebView.swift`, in `loadContent`, replace the base-tag assignment (lines 75-79):

```swift
        if let fileDir = fileURL?.deletingLastPathComponent() {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "<base href=\"\(fileDir.absoluteString)\">")
        } else {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "")
        }
```

with:

```swift
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
```

- [ ] **Step 2: Scope the read-access URL to the temp dir in the MAS build**

In `markdownViewr/MarkdownWebView.swift`, replace the temp-file write + load block (lines 83-93):

```swift
        if let fileDir = fileURL?.deletingLastPathComponent() {
            let tempDir = Self.previewDirectory
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempHTML = tempDir.appendingPathComponent(UUID().uuidString + ".html")
            try? template.write(to: tempHTML, atomically: true, encoding: .utf8)
            // Grant read access to "/" so both the temp file and the document's images are accessible
            webView.loadFileURL(tempHTML, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            context.coordinator.tempFileURL = tempHTML
        } else {
            webView.loadHTMLString(template, baseURL: nil)
        }
```

with:

```swift
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
```

- [ ] **Step 3: Build both variants**

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Release build`
Expected: `BUILD SUCCEEDED`.

Run: `xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual sandbox runtime check**

Launch the Debug-MAS build:
```bash
open "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -configuration Debug-MAS -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app" --args -NSDocumentRevisionsDebugMode YES
```
Then open a markdown file that has a relative local image (e.g. `![](images/x.png)`).
Expected:
1. Text renders immediately; the yellow banner appears.
2. The image is broken/absent before granting.
3. Clicking "Allow Access…" → confirming the folder → the image appears and editing the file on disk live-reloads the view.
4. Closing and re-opening a file in the same folder does NOT show the banner again.

- [ ] **Step 5: Commit**

```bash
git add markdownViewr/MarkdownWebView.swift
git commit -m "feat: scope WKWebView read access to temp dir in MAS build"
```

---

## Task 7: App Store export options + release recipe

**Files:**
- Create: `ExportOptions-MAS.plist`
- Modify: `justfile`

- [ ] **Step 1: Create the App Store export options**

Create `ExportOptions-MAS.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>9MG4YT2G93</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

- [ ] **Step 2: Add the `release-mas` recipe**

Append to `justfile`:

```just
# Archive and export a signed App Store .pkg (then upload via Transporter or altool)
release-mas: kill
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    MAJOR=$(echo "$VERSION" | cut -d. -f1)
    MINOR=$(echo "$VERSION" | cut -d. -f2)
    PATCH=$(echo "$VERSION" | cut -d. -f3)
    BUILD_NUMBER=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))
    echo "==> Regenerating Xcode project..."
    xcodegen generate
    ARCHIVE="/tmp/markdownViewr-mas.xcarchive"
    EXPORT="/tmp/markdownViewr-mas-export"
    rm -rf "$ARCHIVE" "$EXPORT"
    echo "==> Archiving v$VERSION (build $BUILD_NUMBER) for the App Store..."
    xcodebuild archive \
        -project markdownViewr.xcodeproj \
        -scheme markdownViewr \
        -configuration Release-MAS \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" | xcpretty || true
    echo "==> Exporting App Store package..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist ExportOptions-MAS.plist
    PKG=$(find "$EXPORT" -name '*.pkg' | head -1)
    echo ""
    echo "Done! Signed App Store package:"
    echo "  $PKG"
    echo ""
    echo "Upload with Transporter.app, or:"
    echo "  xcrun altool --upload-app -f \"$PKG\" -t macos \\"
    echo "    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
```

- [ ] **Step 3: Verify the recipe is listed**

Run: `just --list`
Expected: `release-mas` appears with its description.

- [ ] **Step 4: Commit**

```bash
git add ExportOptions-MAS.plist justfile
git commit -m "build: add App Store export options and release-mas recipe"
```

Note: actually running `just release-mas` requires an Apple Distribution certificate and provisioning profile that may not exist yet (see Task 8 / out-of-scope account setup). The recipe is verified by listing and by code review here; a full archive+export run happens once the App Store Connect account is set up.

---

## Task 8: External-editor sandbox verification

**Files:**
- Possibly modify: `markdownViewr/EditorConfig.swift:60-74`

This task is a verify-then-decide item, per the design. Do NOT preemptively add bookmarks.

- [ ] **Step 1: Test launching a configured editor under the sandbox**

Launch the Debug-MAS build, configure an external editor in Settings (pick an installed app, e.g. an editor in `/Applications`), open a markdown file, and click the editor toolbar button (`ContentView.swift:231` → `EditorManager.openFile`).
Expected (to determine): does `NSWorkspace.open(_:withApplicationAt:configuration:)` successfully launch the editor with the document, under sandbox, using the stored path string?

- [ ] **Step 2: Branch on the result**

- If it works: no code change. Note the verified behavior in `CLAUDE.md`'s sandbox notes and finish.
- If it fails (no access to the stored editor path across launches): store a security-scoped bookmark for the editor app URL when the user selects it (in the editor-picker flow in `SettingsView`/`EditorConfig`), resolve and `startAccessingSecurityScopedResource()` around the launch in `EditorManager.openFile`, keyed like `FolderAccessManager`. Add `com.apple.security.files.user-selected.read-only` is already present; confirm it suffices for launching.

- [ ] **Step 3: Commit (only if code changed)**

```bash
git add markdownViewr/EditorConfig.swift markdownViewr/SettingsView.swift
git commit -m "fix: bookmark external-editor app access under sandbox"
```

---

## Task 9: Document the new distribution path

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a "Distribution" section to CLAUDE.md**

Add a section documenting: the two build configs (`Release`/`Release-MAS`), what `MAS_BUILD` gates (Sparkle out, sandbox on, folder-access banner, image inlining), the entitlements file, `just release` vs `just release-mas`, and the manual App Store Connect steps that remain (account/cert/profile, app record, screenshots, privacy label, submission). Keep it concise and factual, matching the existing CLAUDE.md style.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document Mac App Store dual-distribution build"
```

---

## Out of scope (manual, cannot be automated from the repo)

- Apple Developer account: register App ID `com.dkelkhoff.markdownViewr`, create **Apple Distribution** + **Mac Installer Distribution** certificates and a provisioning profile.
- App Store Connect: create the app record, upload screenshots, write description/keywords, complete the **App Privacy** label (the app collects nothing), answer export-compliance (no non-exempt crypto).
- Submit the build and respond to App Review.

These should be tracked as a manual checklist outside this plan.
```
