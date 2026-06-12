# markdownViewr

macOS markdown viewer app. View-only — no editing. Built with SwiftUI + WKWebView hybrid architecture.

## Build & Run

Uses XcodeGen to generate the Xcode project from `project.yml`.

```bash
just run          # build and launch
just build        # build only
just generate     # regenerate .xcodeproj from project.yml
just clean        # clean build artifacts
just kill         # force-kill running app
```

After adding/removing Swift files or resources, run `xcodegen generate` before building.

## Distribution

The app ships through **two** channels from one codebase, built from **two application targets** that share a `targetTemplates: AppBase` (sources, resources, swift-markdown, version, bundle id):

| Channel | Target | Scheme | Signing | Updates | Recipe |
|---|---|---|---|---|---|
| **Developer ID** | `markdownViewr` | `markdownViewr` | Developer ID | Sparkle + Homebrew cask | `just release` |
| **Mac App Store** | `markdownViewr-MAS` | `markdownViewr-MAS` | Apple Distribution | App Store | `just release-mas` |

Both targets use the standard `Debug`/`Release` configs (no special `-MAS` configs). They differ ONLY in three things: the `markdownViewr` target depends on the `sparkle` package and the `markdownViewr-MAS` target does not; the MAS target sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS: MAS_BUILD` and applies `markdownViewr/markdownViewr-MAS.entitlements` (sandbox + user-selected read-only + app-scope bookmarks + network client). The Developer ID build is unchanged at runtime — all sandbox behavior is gated behind `#if MAS_BUILD`.

**Why two targets, not one target with two configs:** SwiftPM **auto-links a declared package-product dependency regardless of whether the source imports it**, so `#if !MAS_BUILD` around `import Sparkle` removes Sparkle *usage* but not the *link/embed*. A single target therefore always embeds `Sparkle.framework`, whose non-sandboxable helper executables (Autoupdate, Updater.app, the XPC services) make the App Store reject the build (error 90296). The framework can't be stripped post-build either — the binary links it, so removal causes a dyld launch crash. The only fix is a separate target that doesn't depend on Sparkle at all. (Both targets output `markdownViewr.app` to the same `Build/Products/Release/` in shared DerivedData, so alternating local builds overwrite each other — harmless, since the release recipes archive to their own paths.)

What `MAS_BUILD` / the MAS target changes:

- **No Sparkle** — the MAS target omits the `sparkle` dependency (so nothing is linked or embedded), and `import Sparkle`, `SPUStandardUpdaterController`, and the "Check for Updates…" command are behind `#if !MAS_BUILD` (so the MAS target compiles without the Sparkle module). The `SUFeedURL`/`SUPublicEDKey` Info.plist keys live in the `markdownViewr` target's `info.properties` (so the Developer ID build keeps them); the MAS target reuses that generated `Info.plist` and deletes those two keys in its unconditional `Strip Sparkle keys from MAS Info.plist` post-build script. (`INFOPLIST_KEY_`-prefixed injection does NOT work for non-Apple custom keys — verified — hence the post-build strip.)
- **Folder access** — `FolderAccessManager` resolves/persists an app-scoped security-scoped bookmark for the open document's folder, used only to read sibling images. The grant banner is shown **only when the document actually references local images** (`ImageInliner.containsLocalImage`) and access isn't held yet — image-less docs (the common case) never prompt. Bookmarks are keyed by folder path in `UserDefaults` (`folderBookmark:<path>`).
- **File watching is decoupled from the grant** — `ContentView` starts the `FileWatcher` unconditionally on open. The opened document is accessible via the document architecture, so live-reload works for every doc with no prompt; the folder bookmark is needed only for sibling images.
- **Image inlining** — `ContentView.rerender()` rewrites relative-local `<img>` tags to `data:` URLs via `ImageInliner`, reading bytes through the folder bookmark. This makes the preview HTML self-contained so `MarkdownWebView` only grants WKWebView read access to the container temp dir (not `/`). Remote images load via the network-client entitlement.
- **External editors** — verified to work under sandbox via `NSWorkspace.open(_:withApplicationAt:)` with the stored path string; LaunchServices mediates the launch, so no per-editor bookmark is needed.

**Remaining manual App Store Connect steps** (not automated): register the App ID and create Apple Distribution + Mac Installer Distribution certificates and a provisioning profile; create the app record; upload screenshots; write the App Privacy label (collects nothing) and export-compliance answer (no non-exempt crypto); submit for review.

## Architecture

- **SwiftUI** app shell (toolbar, settings, window management)
- **WKWebView** for markdown rendering (via `NSViewRepresentable`)
- **Document-based** using `DocumentGroup` with `FileDocument`
- Markdown parsed to HTML using Apple's `swift-markdown` library
- HTML rendered in a template (`Resources/template.html`) with CSS variable-based theming
- Settings and Theme Editor use custom `NSWindow` controllers (not SwiftUI `Settings` scene) because SwiftUI's Settings scene doesn't support resizing

## Portability (Apple platforms)

The app can grow to iOS/iPadOS/visionOS without a rewrite, provided one boundary stays clean: the render/model core must stay free of AppKit.

- **Portable core (pure Swift / web — reuse as-is):** markdown→HTML (`MarkdownDocument`, swift-markdown), `ImageInliner`, `Theme`/`ThemeManager`, and the entire render layer (`Resources/template.html`, CSS, JS). Keep `NS*`/AppKit types out of these files.
- **Platform layer (macOS-bound — needs per-platform twins):** `MarkdownWebView` (`NSViewRepresentable` → `UIViewRepresentable`; WKWebView itself exists on iOS), `SettingsWindowController`/`HelpWindowController` (`NSWindow` → sheets/navigation), `FolderAccessManager` (`NSOpenPanel` → `UIDocumentPickerViewController`), `EditorManager`/`EditorConfig` (`NSWorkspace` external-editor launch — no iOS equivalent), `WindowResizer`/`WindowAccessor`.
- `DocumentGroup` (app entry) is already cross-platform. The MAS sandboxing also moves macOS toward the always-sandboxed iOS model (security-scoped access instead of broad file reads), so it helps rather than hinders an iOS port.

Don't build cross-platform abstractions speculatively — just keep the render/model code AppKit-free until a second platform is actually on the table.

## Key Files

| File | Purpose |
|---|---|
| `MarkdownViewrApp.swift` | App entry point, `DocumentGroup`, menu commands, `SettingsWindowController` |
| `MarkdownDocument.swift` | `FileDocument`, markdown-to-HTML conversion, frontmatter parsing |
| `ContentView.swift` | Main window: toolbar, find bar, `LiveContent` for file watching |
| `MarkdownWebView.swift` | `NSViewRepresentable` wrapping `WKWebView`, handles content/theme/find updates |
| `Theme.swift` | `Codable` theme model (colors, fonts, sizes, customCSS). `isBuiltIn` is runtime-only (not in JSON) |
| `ThemeManager.swift` | Loads/saves themes, generates CSS, manages enabled/disabled/deleted state |
| `ThemeEditorView.swift` | Theme creation/editing UI with live preview |
| `SettingsView.swift` | General, Editors, Themes tabs + `ThemeEditorWindowController` |
| `EditorConfig.swift` | External editor model + manager |
| `ImageInliner.swift` | Rewrites relative-local `<img>` tags to `data:` URLs (MAS build only) |
| `FolderAccessManager.swift` | Security-scoped folder access via app-scoped bookmarks (MAS build only) |
| `FileWatcher.swift` | `DispatchSource` file system watcher |
| `FindBarController.swift` | Find state + notification names |
| `CSSHelpView.swift` | Shared CSS reference popover |
| `SampleMarkdown.swift` | Kitchen-sink sample for theme preview |
| `WindowResizer.swift` | NSView helper that adds `.resizable` to hosting windows |
| `Resources/template.html` | HTML template with base CSS, theme CSS slot, and JS functions |
| `Resources/themes/*.json` | Built-in theme definitions |

## How Theming Works

1. `ThemeManager.generateCSS(for:)` produces CSS with `:root` variables from the theme, plus global CSS, plus per-theme custom CSS
2. CSS is injected into the `<style id="theme-css">` block in the template (comes AFTER base CSS so custom CSS can override)
3. Theme switching uses `evaluateJavaScript("updateThemeCSS(...)")` to avoid full page reload
4. Content updates use `evaluateJavaScript("updateContent(...)")` with scroll position preservation

## How File Watching Works

- `LiveContent` (ObservableObject) stores raw markdown, updated by `FileWatcher`
- `ContentView.rerender()` converts raw markdown to HTML using current frontmatter mode
- Updates pushed to WebView via JS `updateContent()` to preserve scroll position
- `onReceive` on `themeManager.$frontmatterMode` and `liveContent.$rawMarkdown` trigger re-renders (with `DispatchQueue.main.async` to avoid stale `@Published` values)

## How Images Work

- HTML is written to a temp file in `/tmp/markdownViewr-previews/`
- Loaded via `WKWebView.loadFileURL` with `allowingReadAccessTo: /`
- A `<base href="...">` tag in the HTML points to the document's directory so relative image paths resolve correctly

## Settings Windows

SwiftUI's `Settings` scene and `.sheet` don't support resizing on macOS. Both Settings and Theme Editor use manually created `NSWindow` instances via controller classes (`SettingsWindowController`, `ThemeEditorWindowController`).

## Theme Storage

- Built-in themes: bundled JSON in `Resources/themes/`
- User themes: `~/Library/Application Support/markdownViewr/themes/`
- Disabled themes tracked in UserDefaults key `disabledThemes`
- Deleted built-in themes tracked in UserDefaults key `deletedBuiltIns` (restorable)
- Theme order tracked in UserDefaults key `themeOrder`
- Active theme tracked in UserDefaults key `activeTheme`

## Theme Schema Versioning

Theme JSON files carry a `schemaVersion` integer field. The current version is in `Theme.currentSchemaVersion` (`Theme.swift`).

**When you add a new field to `Theme`, `ThemeColors`, `ThemeFonts`, or `ThemeSizes`:**

1. Increment `Theme.currentSchemaVersion`.
2. Add the new field with a sensible default in `init(from decoder:)` using `decodeIfPresent` so older files still load.
3. Update the built-in theme JSON files in `Resources/themes/` with the new field.
4. Add a migration step in `ThemeManager.migrateIfNeeded(_ theme: inout Theme)` — an `if theme.schemaVersion < N` block that fills in the new field and bumps `schemaVersion` to `N`. Stack these in order so a theme several versions behind migrates fully in one pass. `migrateIfNeeded` is already called from `loadUserThemes()` (with automatic write-back to disk if the version changed) and from `importTheme(_:resolution:)`. Do not remove the example comment block — it shows future-me the pattern.
5. Update `ThemeEditorView` to expose any new user-facing fields.
6. Update `ThemeManager.generateCSS(for:)` if the new field affects rendering.

**Import behaviour (already implemented in `SettingsView.importThemes()`):** if an imported theme's `schemaVersion` exceeds `currentSchemaVersion`, the user is warned before import proceeds. If it is lower, run `migrateIfNeeded` on it during import just as you would for any loaded theme.

**Schema version history:**

| Version | What changed |
|---|---|
| 1 | Initial versioned schema (colors, fonts, sizes, customCSS) |

## Find in Document

- Cmd+F toggles find bar per-window (each window has its own `FindBarController`)
- Menu commands post notifications; only the key window responds
- Uses custom JavaScript (`findAll`, `findNext`, `findPrev`, `clearFind`) that highlights matches with `<mark>` elements
- Highlights use theme-aware colors (`--text` and `--link` variables) to work on any background
- Returns JSON `{current, total}` for "n of m" display

## Gotchas

- `Bundle.module` doesn't exist in XcodeGen projects — always use `Bundle.main`
- `Table` is ambiguous between SwiftUI and Markdown — use `Markdown.Table`
- SwiftUI computed properties reading `@Published` values via `onReceive` fire BEFORE the value is set — use `DispatchQueue.main.async` to defer
- `NSWindow.isReleasedWhenClosed` must be `false` for windows held by controllers, with `windowWillClose` delegate to nil the reference
