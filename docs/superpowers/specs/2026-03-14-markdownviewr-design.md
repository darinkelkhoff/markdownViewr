# markdownViewr — Design Spec

## Overview

A macOS markdown viewer app built with SwiftUI. View-only — no editing. Files open in separate windows. Theming via color palettes with optional CSS overrides. External editor integration for when you need to edit.

## Architecture

**Hybrid approach:** SwiftUI app shell (toolbar, settings, window management) + WKWebView for markdown rendering. This gives native macOS controls with rich HTML/CSS-based content rendering.

**Document-based app** using `DocumentGroup` for multi-window support. Each `.md` file opens in its own window.

## File Opening

- Registers as a `.md` file handler (user can set as default in Finder)
- Supports drag-and-drop onto the app icon and windows
- File > Open picker
- All three methods supported simultaneously
- If a file is already open in another window, focus that window instead of opening a duplicate

## Window Layout

Single-pane rendered view:

```
┌─────────────────────────────────────────┐
│ ● ● ●        README.md                 │  ← macOS title bar
├─────────────────────────────────────────┤
│              [Catppuccin ▼] [↗ Edit]    │  ← toolbar (right-aligned)
├─────────────────────────────────────────┤
│                                         │
│  # Project Title                        │
│                                         │
│  A description of the project...        │
│                                         │
│  ## Installation                        │
│  ┌─────────────────────────────┐        │
│  │ $ brew install foo          │        │  ← WKWebView content area
│  └─────────────────────────────┘        │
│                                         │
│  ## Features                            │
│  - Item one                             │
│  - Item two                             │
│                                         │
└─────────────────────────────────────────┘
```

### Toolbar Controls

- **Palette picker**: Dropdown with color dot preview + palette name
- **Editor button**: Smart behavior — direct click if one editor configured, dropdown menu if multiple

## Theming System

### Two-Layer Architecture

**Layer 1 — Theme Properties (no CSS knowledge needed):**

| Property | Description | Example |
|---|---|---|
| `background` | Page background | `#1e1e2e` |
| `text` | Body text color | `#cdd6f4` |
| `heading1` | H1 color | `#cba6f7` |
| `heading2` | H2 color | `#89b4fa` |
| `heading3` | H3 color | `#89b4fa` |
| `heading4` | H4 color | `#74c7ec` |
| `heading5` | H5 color | `#74c7ec` |
| `heading6` | H6 color | `#74c7ec` |
| `link` | Link color | `#89dceb` |
| `codeBackground` | Code block background | `#181825` |
| `codeText` | Code text color | `#a6e3a1` |
| `blockquoteBorder` | Blockquote accent | `#cba6f7` |
| `font` | Body font family | `System` |
| `codeFont` | Code font family | `SF Mono` |
| `baseFontSize` | Body text size | `14` |
| `h1Size` | H1 font size | `28` |
| `h2Size` | H2 font size | `23` |
| `h3Size` | H3 font size | `20` |
| `h4Size` | H4 font size | `18` |
| `h5Size` | H5 font size | `16` |
| `h6Size` | H6 font size | `15` |
| `codeFontSize` | Code text size | `13` |
| `lineHeight` | Line height multiplier | `1.7` |

**Layer 2 — Custom CSS (optional, for power users):**

Raw CSS string that gets injected after the theme properties CSS. Can override anything.

### Theme Storage Format

```json
{
  "name": "My Custom Theme",
  "colors": {
    "background": "#1e1e2e",
    "text": "#cdd6f4",
    "heading1": "#cba6f7",
    "heading2": "#89b4fa",
    "heading3": "#89b4fa",
    "heading4": "#74c7ec",
    "heading5": "#74c7ec",
    "heading6": "#74c7ec",
    "link": "#89dceb",
    "codeBackground": "#181825",
    "codeText": "#a6e3a1",
    "blockquoteBorder": "#cba6f7"
  },
  "fonts": {
    "body": "System",
    "code": "SF Mono"
  },
  "sizes": {
    "baseFontSize": 14,
    "h1Size": 28,
    "h2Size": 23,
    "h3Size": 20,
    "h4Size": 18,
    "h5Size": 16,
    "h6Size": 15,
    "codeFontSize": 13,
    "lineHeight": 1.7
  },
  "customCSS": ""
}
```

- Built-in themes are bundled in the app
- User themes stored in `~/Library/Application Support/markdownViewr/themes/`

### Built-in Palettes

1. **Catppuccin Mocha** — dark, pastel accents
2. **Dracula** — dark, vibrant purples and greens
3. **Rosé Pine Dawn** — light, warm muted tones
4. **GitHub Light** — light, familiar GitHub styling
5. **Solarized Dark** — dark, classic warm/cool balance
6. **GitHub Dark** — dark, familiar GitHub styling

## External Editor Integration

Users configure a list of editors in Settings. Each entry stores:
- App name (display label)
- App bundle path (e.g., `/Applications/Visual Studio Code.app`)
- Option for "open document's folder" (useful for opening a terminal or even Finder)

**Toolbar button behavior:**
- 1 editor configured → button clicks directly open in that editor
- 2+ editors configured → button shows dropdown menu of editors

Opens the current file using `NSWorkspace.shared.open(_:withApplicationAt:configuration:)`.

If a configured editor has been moved or uninstalled, show an alert and offer to remove it from the list.

### Settings UI

- List of configured editors
- Add editor: browse `/Applications` or drag app icon
- Remove editor: swipe-to-delete or minus button
- Theme management: select active palette, create/edit/delete custom themes

## Components

| File | Purpose |
|---|---|
| `MarkdownViewrApp.swift` | App entry point, `DocumentGroup` setup |
| `MarkdownDocument.swift` | `FileDocument` conformance, reads `.md` files |
| `ContentView.swift` | Main window view: toolbar + web view |
| `MarkdownWebView.swift` | `NSViewRepresentable` wrapping `WKWebView` |
| `ThemeManager.swift` | Loads built-in + user themes, applies to web view |
| `Theme.swift` | `Codable` theme model |
| `SettingsView.swift` | Editor list + theme management |
| `Resources/template.html` | Base HTML template with CSS variable slots |
| `Resources/themes/` | Built-in theme JSON files |

## Rendering Pipeline

1. `MarkdownDocument` reads raw `.md` text from file
2. Swift parses markdown to HTML using Apple's `swift-markdown` (via Swift Package Manager)
3. `ThemeManager` generates CSS from active theme's properties + custom CSS
4. HTML template is populated with content HTML + theme CSS
5. `WKWebView` loads the complete HTML string
6. On theme change: re-inject CSS without re-parsing markdown

## Verification

1. Build and run in Xcode
2. Open a `.md` file via File > Open — verify rendered output
3. Drag a `.md` file onto the dock icon — verify it opens in a new window
4. Switch between built-in palettes — verify colors change
5. Create a custom theme JSON, place in `~/Library/Application Support/markdownViewr/themes/` — verify it appears in picker
6. Add a custom CSS override to a theme — verify it applies
7. Configure an external editor in Settings — verify the toolbar button opens the file
8. Configure multiple editors — verify the button becomes a dropdown
9. Open multiple files — verify each opens in its own window
