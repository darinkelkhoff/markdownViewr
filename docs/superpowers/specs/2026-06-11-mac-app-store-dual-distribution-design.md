# Mac App Store Dual-Distribution — Design

**Date:** 2026-06-11
**Branch:** `mas-dual-distribution`
**Status:** Approved (design); implementation pending

## Goal

Ship markdownViewr through **two** distribution channels from one codebase:

1. **Developer ID** (existing) — notarized `.app` in a DMG, Sparkle auto-update, Homebrew cask. Unchanged by this work.
2. **Mac App Store (MAS)** (new) — sandboxed `.pkg`, updates delivered by the App Store, no Sparkle.

The two builds differ only where the sandbox forces them to. All sandbox-specific code is isolated behind a `MAS_BUILD` compile-time flag so the Developer ID build remains byte-for-byte what it is today.

## Constraints discovered in the code

Three sandbox blockers exist in the current code:

| # | Blocker | Location |
|---|---------|----------|
| 1 | Sparkle third-party updater (forbidden on MAS) | `MarkdownViewrApp.swift:2,6`; `Info.plist` `SUFeedURL`/`SUPublicEDKey` |
| 2 | File watching opens the doc fd directly and re-reads it | `FileWatcher.swift:20`; `ContentView.swift:10` |
| 3 | `loadFileURL(..., allowingReadAccessTo: "/")` + relative images live in the doc's folder, which the sandbox does not grant access to | `MarkdownWebView.swift:89` |

## Architecture

### 1. Build structure

- Keep the single `markdownViewr` application target.
- Add build configurations **`Release-MAS`** and **`Debug-MAS`** in `project.yml` (via the `configs` map and per-config `settings`).
- `Release-MAS` / `Debug-MAS` set:
  - `ENABLE_APP_SANDBOX: YES`
  - `CODE_SIGN_ENTITLEMENTS: markdownViewr/markdownViewr-MAS.entitlements`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS: MAS_BUILD` (appended to existing conditions for that config)
- The existing `Release`/`Debug` configs are untouched. Developer ID path is unchanged.
- Bundle ID stays `com.dkelkhoff.markdownViewr` for both — Developer ID and MAS builds may share it.

### 2. Sparkle (Blocker 1)

- Wrap the `import Sparkle`, the `updaterController` property, and the "Check for Updates…" command in `#if !MAS_BUILD` in `MarkdownViewrApp.swift`.
- Sparkle remains a Swift Package dependency (still linked), but no Sparkle runtime calls compile into the MAS binary.
- Move the `SUFeedURL` and `SUPublicEDKey` keys out of the shared `Info.plist` so they are absent from the MAS bundle. (Mechanism: a non-MAS-only Info.plist injection via `project.yml` `info.properties` scoped to the non-MAS configs, or a separate plist for MAS. Exact mechanism resolved during implementation; requirement is: MAS bundle must not contain Sparkle feed keys.)
- Update `HelpView.swift:54` ("Automatic updates via Sparkle") to not advertise Sparkle in the MAS build.

### 3. Folder access subsystem (Blockers 2 + 3) — all behind `#if MAS_BUILD`

New type `FolderAccessManager`:

- **Input:** a document URL.
- **Lookup:** finds a persisted **app-scoped security-scoped bookmark** for the document's parent folder, keyed by folder path (stored in `UserDefaults`).
- **Resolve + hold:** resolves the bookmark and holds `startAccessingSecurityScopedResource()` for the document window's lifetime; releases on close.

First-time-folder flow (no stored bookmark):

1. Document renders immediately — the markdown text is already available from DocumentGroup, so **text is never gated** on folder access.
2. A dismissible banner appears in the document window: *"Allow access to this file's folder to show images and auto-reload on changes."*
3. Button presents an `NSOpenPanel` pre-pointed at the document's folder. User confirms.
4. App creates and persists an app-scoped security-scoped bookmark for the folder, then re-renders (images now resolve) and starts file-watching.
5. That folder never prompts again on subsequent opens.

This single grant powers both remaining blockers:

- **File watching (Blocker 2):** `open(path, O_EVTONLY)` and re-reading the doc succeed while folder access is held. `FileWatcher`/`LiveContent` start only after access is acquired in the MAS build; in the non-MAS build they start immediately as today.
- **Image reads (Blocker 3):** see below.

### 4. Image handling (Blocker 3)

The "load file vs inline" choice collapses under sandbox: `loadFileURL(_:allowingReadAccessTo:)` grants exactly **one** directory subtree, but the preview HTML lives in the app container temp dir while images live in the user's doc folder — two distinct trees. Writing the preview HTML into the user's folder would litter it and require a read-write grant.

Therefore:

- **MAS build:** at render time, resolve relative local image references, read the image bytes **through the held folder bookmark**, and inline them as `data:` URLs in the HTML. The preview HTML becomes self-contained, stays in the container temp dir, and `allowingReadAccessTo` only needs the temp dir. Remote (`http`/`https`) images are left as-is and load via the network-client entitlement.
- **Non-MAS build:** unchanged — temp file + `allowingReadAccessTo: "/"`, no inlining, `<base href>` resolves relative images.

Implementation isolates the divergence in `MarkdownWebView.loadContent` (and a render-time image-inlining helper) behind `#if MAS_BUILD`.

### 5. Entitlements — `markdownViewr/markdownViewr-MAS.entitlements`

- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-only` = true
- `com.apple.security.files.bookmarks.app-scope` = true
- `com.apple.security.network.client` = true (remote images)

### 6. External editors — verify during implementation

`EditorManager.openFile` (`EditorConfig.swift:73`) launches a user-configured editor via `NSWorkspace.open(_:withApplicationAt:configuration:)` using a stored **path string**. Under sandbox the stored path may not be accessible across launches without its own security-scoped bookmark.

Plan: treat as a scoped sub-task. During implementation, test whether Launch Services still permits launching an installed editor from a bare path under sandbox. If not, store a per-editor security-scoped bookmark when the user picks the editor and resolve it at launch time. Do not solve preemptively; confirm the actual sandbox behavior first.

### 7. Release pipeline

- New `ExportOptions-MAS.plist` with `method: app-store`.
- New `just release-mas` recipe: archive with the `Release-MAS` config + Apple Distribution signing, export a `.pkg`, upload via `notarytool`/Transporter.
- Existing `just release` (Developer ID → DMG → notarize → GitHub release → appcast → Homebrew) is untouched.

## Out of scope

Manual / App Store Connect portal steps that cannot be done from the repo:

- Apple Developer account / App ID registration, Apple Distribution + Mac Installer Distribution certificates, provisioning profile.
- App Store Connect app record, screenshots, description/keywords, App Privacy nutrition label, export-compliance answers.
- The actual submission and App Review.

These will be documented as a checklist but are not implemented here.

## Testing

- **Builds:** both `Release` and `Release-MAS` compile and link; MAS binary contains no Sparkle feed keys and no Sparkle runtime symbols are exercised.
- **Sandbox runtime (MAS Debug):** open a doc with relative local images → text renders immediately, banner appears, granting folder access shows images and enables live-reload; second open of a doc in the same folder does not prompt.
- **Non-MAS regression:** Developer ID build behavior (images, watching, Sparkle update check) is unchanged.
- **External editors:** launch a configured editor from the sandboxed build; confirm it works or that the bookmark fallback works.
- Existing unit tests (`markdownViewrTests`) continue to pass under both configs.
