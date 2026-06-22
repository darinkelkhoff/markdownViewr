import SwiftUI
import WebKit

private enum HelpTopic: String, CaseIterable, Identifiable {
    case overview       = "Overview"
    case openingFiles   = "Opening Files"
    case headings       = "Headings"
    case tableOfContents = "Table of Contents"
    case sourceView     = "Source View"
    case frontmatter    = "Frontmatter"
    case extensions     = "Markdown Extensions"
    case themes         = "Themes"
    case customCSS      = "Custom CSS"
    case editors        = "External Editors"
    case shortcuts      = "Keyboard Shortcuts"

    var id: String { rawValue }
}

struct HelpView: View {
    @State private var selection: HelpTopic = .overview

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allCases, selection: $selection) { topic in
                Text(topic.rawValue).tag(topic)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            HelpWebView(markdown: helpMarkdown(for: selection))
                .id(selection)
        }
    }

    private func helpMarkdown(for topic: HelpTopic) -> String {
        switch topic {
        case .overview:
            var overview = """
            # Overview

            markdownViewr is a fast, view-only markdown file viewer for macOS. It renders \
            markdown to HTML and displays it in a styled WebView with full theming support.

            Files are watched for external changes and automatically reloaded — open a file \
            in your editor and markdownViewr keeps pace as you save.

            ## Features

            - Renders standard Markdown and GitHub Flavored Markdown (GFM): bold, italic, \
            strikethrough, tables, code blocks, task lists, and more
            - Optional extensions: highlight, superscript, subscript, underline
            - YAML frontmatter support: hide it, show it as a metadata table, or render it as Markdown
            - Fully customizable themes with a built-in theme editor and custom CSS
            - Resizable table of contents with depth markers
            - Side-by-side Markdown source view, synced to the rendered document
            - Collapsible outline: click a heading to collapse its section, ⌥-click to anchor to it
            - Max content width setting to keep line lengths readable on wide monitors
            - Vim-style keyboard navigation
            - Find in document with match count
            - One-click open in any configured external editor
            """
            #if !MAS_BUILD
            overview += "\n- Automatic updates via Sparkle"
            #endif
            return overview

        case .openingFiles:
            return """
            # Opening Files

            markdownViewr opens any plain text file. It registers `.md`, `.markdown`, \
            `.mdown`, and `.mkd` with the OS so Finder offers markdownViewr for those \
            file types by default.

            ## Ways to open a file

            - **File > Open** (⌘O) — standard open dialog
            - Drag a file onto the Dock icon or an open window
            - Double-click a file in Finder if markdownViewr is set as the default app
            - Right-click a file in Finder > Open With > markdownViewr

            ## Setting as the default viewer

            To make markdownViewr open all `.md` files by default: right-click any `.md` \
            file in Finder, choose **Get Info**, expand **Open with**, select markdownViewr, \
            then click **Change All...**.

            ## Live reloading

            When an open file is modified on disk by another app (your editor, a script, \
            etc.), markdownViewr detects the change and re-renders automatically. Scroll \
            position is preserved across reloads.
            """

        case .headings:
            return """
            # Headings

            Headings in the rendered document are interactive:

            - **Click** a heading to collapse or expand its section. Collapsing also \
            collapses the matching section in the source view (if open), leaving a ⋯ \
            placeholder.
            - **⌥-click** (Option-click) a heading to anchor it to the top of the view; \
            the table of contents and source view follow along.

            You can also jump between headings with `]]` / `[[` (see Keyboard Shortcuts), \
            or click an entry in the table of contents.
            """

        case .tableOfContents:
            return """
            # Table of Contents

            Toggle the table of contents with the list button in the toolbar. It lists \
            the document's headings and highlights the section you're currently reading. \
            Click an entry to jump to that heading.

            ## Controls

            - **Show / hide** — the list-bullet button in the toolbar.
            - **Depth** — the H1–H6 picker in the toolbar controls how many heading levels to include.
            - **Resize** — drag the divider on the panel's right edge. The width is \
            remembered across documents and launches.

            ## Display options (Settings > General)

            - **Wrap long entries** — off by default; long headings are truncated with an \
            ellipsis (hover an entry to see its full text).
            - **Depth markers** — prefix each entry with a shape that varies by heading \
            level (●, ○, ◆, ◇, ■, □) so the outline depth is easy to scan.
            """

        case .sourceView:
            return """
            # Source View

            Toggle the raw Markdown source with the document button in the toolbar to show \
            it in a pane beside the rendered view.

            ## Behavior

            - **Resize** — drag the divider on the pane's left edge; the width is remembered.
            - **Find** — ⌘F searches both panes at once, and Next / Previous move the \
            rendered and source views together to the same match.
            - **Scroll-sync** — scrolling either pane keeps the other aligned to the same \
            heading.
            - **Collapsing** — collapsing a section in the rendered view also collapses it \
            in the source, leaving a ⋯ placeholder.

            The source pane is read-only — markdownViewr is a viewer, not an editor. To \
            edit, use **Open in external editor**.

            ## Customizing

            The source pane and table of contents can be restyled with custom CSS \
            (Settings > General > Global Custom CSS, or a theme's Custom CSS). See the CSS \
            reference — the **?** button — for selectors such as `#raw-source` and `#toc`.
            """

        case .frontmatter:
            return """
            # Frontmatter

            YAML frontmatter is a block of metadata at the very top of a Markdown file, \
            delimited by `---` lines:

            ```
            ---
            title: My Document
            author: Jane Smith
            date: 2026-01-01
            ---

            # Heading

            Body text...
            ```

            The **Frontmatter** setting (Settings > General) controls how this block is handled.

            ## Hide (default)

            The frontmatter block is stripped before rendering. The body begins immediately \
            after the closing `---` line.

            ## Show as Metadata

            The frontmatter is rendered as a styled key–value table above the document body. \
            Keys appear on the left, values on the right.

            ## Show as Markdown

            The frontmatter is passed to the Markdown parser as-is. The `---` delimiters \
            render as horizontal rules and the content is treated as normal Markdown text.
            """

        case .extensions:
            return """
            # Markdown Extensions

            Extensions add syntax beyond standard GFM. Each can be toggled independently \
            in **Settings > Extensions**.

            ## Highlight

            Wrapping text in `== ==` renders it as highlighted text.

            ```
            ==highlighted text==
            ```

            ## Superscript

            Wrapping a single word in `^ ^` renders it as superscript. No spaces allowed \
            inside — this avoids false positives on prose like "It's ^ that simple".

            ```
            E = mc^2^

            Footnote reference^1^
            ```

            ## Subscript

            Wrapping a single word in `~ ~` renders it as subscript. No spaces allowed \
            inside — single-word only to avoid conflict with GFM strikethrough (`~~ ~~`).

            ```
            H~2~O

            CO~2~
            ```

            ## Underline

            Wrapping text in `++ ++` renders it as underlined text.

            ```
            ++underlined text++
            ```

            ## Standard GFM (always on)

            - `**bold**` / `__bold__`
            - `*italic*` / `_italic_`
            - `~~strikethrough~~`
            - `` `inline code` ``
            - Fenced code blocks
            - Tables
            - `- [ ]` task lists
            """

        case .themes:
            return """
            # Themes

            Themes control the colors, fonts, and overall appearance of rendered documents. \
            markdownViewr ships with a set of built-in themes and supports unlimited \
            user-created themes.

            ## Switching themes

            Use the **Theme** menu or the keyboard shortcuts **⌘⇧↓** / **⌘⇧↑** to cycle \
            through enabled themes. The active theme applies to all open windows.

            ## Managing themes

            **Settings > Themes** lists all themes. You can:

            - Enable or disable themes (disabled themes are skipped when cycling)
            - Reorder themes by dragging
            - Delete user themes
            - Restore deleted built-in themes
            - Import themes from `.json` files (one or more at a time)
            - Export the selected theme as a `.json` file to share or back up

            ## Creating and editing themes

            Click **New** (or **Edit** on an existing user theme) to open the Theme \
            Editor. Changes are previewed live against a sample document.

            The editor covers:

            - Background and text colors
            - Heading, link, inline code, and blockquote colors
            - Table border and alternating row colors
            - Body, heading, and code font families and sizes
            - Custom CSS — injected after all base styles, so any rule can be overridden

            ## Custom CSS

            Custom CSS is the escape hatch for anything the theme editor doesn't expose. \
            It targets the same HTML the renderer produces, so standard CSS selectors work. \
            Open the CSS Reference from the Custom CSS editor for a deeper selector guide, \
            including document layout, source pane, table of contents, and scrollbar selectors.

            ```css
            /* Wider line spacing */
            body { line-height: 1.9; }

            /* Justify paragraphs */
            p { text-align: justify; }

            /* Larger code font */
            code { font-size: 0.95em; }

            /* Softer scrollbar thumbs */
            ::-webkit-scrollbar-thumb {
                background: color-mix(in srgb, var(--text) 30%, var(--bg));
            }
            ```

            Useful targets include `#content-inner` for the rendered document body, \
            `#raw-source` for the source pane, `#toc` for the table of contents, and \
            `#content::-webkit-scrollbar-thumb` / `#raw-source::-webkit-scrollbar-thumb` \
            for pane-specific scrollbars.

            ## Max Content Width

            **Settings > General > Max Content Width** limits how wide the document content \
            grows. Enable the checkbox and drag the slider to set a maximum width in pixels. \
            The width scales with zoom so the proportions stay consistent when you zoom in or out.

            This is useful on wide monitors where full-width text lines become hard to read. \
            A value around 800–1000 px works well for most documents.

            ## Theme storage

            User themes are stored as JSON files in \
            `~/Library/Application Support/markdownViewr/themes/`. Built-in themes are \
            bundled with the app and cannot be edited (but can be copied).
            """

        case .customCSS:
            return """
            # Custom CSS

            Custom CSS is injected after markdownViewr's built-in styles and theme variables, \
            so it can override the rendered document, table of contents, source pane, and \
            scrollbars.

            Add global CSS in **Settings > General > Global Custom CSS**, or add per-theme CSS \
            from the Theme Editor. The CSS Reference button opens a deeper selector guide with \
            the app's current HTML structure.

            ## Custom CSS Reference

            The main panes are siblings:

            ```text
            body
              nav#toc
              div#toc-resizer
              div#content
                div#content-inner
              div#raw-resizer
              div#raw-source
                pre > code
            ```

            Use `#content-inner` for rendered document body styles such as padding, background, \
            or prose layout. Use `#content` only when you mean the rendered document scroll pane.

            ## Useful selectors

            | Selector | Target |
            |---|---|
            | `#content-inner` | Rendered document body |
            | `h1` ... `h6` | Rendered headings |
            | `.collapse-arrow` | Heading disclosure marker |
            | `.frontmatter` | Rendered frontmatter table |
            | `#toc` | Table of contents pane |
            | `#toc a.active` | Current table-of-contents entry |
            | `#raw-source` | Markdown source pane |
            | `#raw-source pre` | Source text block |
            | `#raw-source .raw-h` | Source heading lines |

            ## Scrollbars

            markdownViewr uses WebKit scrollbar pseudo-elements. You can style every scrollbar, \
            or scope styles to one pane:

            ```css
            /* All scrollbars */
            ::-webkit-scrollbar { width: 12px; height: 12px; }
            ::-webkit-scrollbar-track { background: var(--bg); }
            ::-webkit-scrollbar-thumb {
                background: color-mix(in srgb, var(--text) 30%, var(--bg));
                border: 3px solid var(--bg);
                border-radius: 999px;
            }
            ::-webkit-scrollbar-thumb:hover { background: var(--link); }
            ::-webkit-scrollbar-corner { background: var(--bg); }

            /* Pane-specific scrollbar thumbs */
            #content::-webkit-scrollbar-thumb { background: var(--h1); }
            #toc::-webkit-scrollbar-thumb { background: var(--h2); }
            #raw-source::-webkit-scrollbar-thumb { background: var(--link); }
            ```

            ## Examples

            ```css
            /* Add heading underlines */
            h1, h2 {
                border-bottom: 1px solid color-mix(in srgb, var(--text) 20%, transparent);
                padding-bottom: 0.25em;
            }

            /* Recolor the Markdown source pane */
            #raw-source, #raw-source pre,
            #raw-source code { background: var(--code-bg); }
            #raw-source code { color: var(--code-text); }
            #raw-source .raw-h { color: var(--h2); }

            /* Style the active table-of-contents entry */
            #toc a.active { color: var(--h1); }
            ```
            """

        case .editors:
            return """
            # External Editors

            markdownViewr can open the current file in an external editor with one click. \
            Any app that accepts a file path as a command-line argument can be configured.

            ## Adding an editor

            Go to **Settings > Editors** and click the **+** button. Give the editor a name, \
            then click the path field to browse for the executable or app bundle. Most \
            editors install a command-line tool (e.g. `/usr/local/bin/code` for VS Code), \
            but you can also browse directly to the `.app` in `/Applications`.

            Enable **Opens folder instead of file** if the editor works better when opened \
            to the containing directory rather than the file itself — useful for \
            project-based editors like VS Code, terminal emulators like Terminal \
            (`/System/Applications/Utilities/Terminal.app`), or Finder \
            (`/System/Library/CoreServices/Finder.app`).

            ## Using the toolbar button

            When at least one editor is configured, an **Open In** button appears in the \
            document toolbar. Click it to open the current file (or its containing folder) \
            in your configured editor. If you have multiple editors configured, clicking \
            the button shows a menu to choose which one.
            """

        case .shortcuts:
            return """
            # Keyboard Shortcuts

            ## Navigation

            | Key | Action |
            |---|---|
            | `j` / `k` | Scroll down / up one line |
            | `Ctrl+d` / `Ctrl+u` | Scroll half page down / up |
            | `Ctrl+f` / `Ctrl+b` | Scroll full page down / up |
            | `g g` | Jump to top of document |
            | `G` | Jump to bottom of document |
            | `]]` / `[[` | Jump to next / previous heading |

            ## Find

            | Key | Action |
            |---|---|
            | `⌘ F` | Show / hide find bar |
            | `⌘ G` | Find next match |
            | `⌘ ⇧ G` | Find previous match |
            | `/` (in document) | Focus find bar (vim-style) |
            | `n` / `N` (in document) | Next / previous match (vim-style) |

            ## View

            | Key | Action |
            |---|---|
            | `⌘ +` | Zoom in |
            | `⌘ −` | Zoom out |
            | `⌘ 0` | Actual size |
            | `⌘ ⇧ ↓` | Next theme |
            | `⌘ ⇧ ↑` | Previous theme |

            ## General

            | Key | Action |
            |---|---|
            | `⌘ ,` | Open Settings |
            | `⌘ ?` | Open Help |
            | `⌘ O` | Open file |
            | `⌘ W` | Close window |
            """
        }
    }
}

struct HelpWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let body = MarkdownDocument.convertToHTML(markdown)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            line-height: 1.6;
            color: #1a1a1a;
            background: transparent;
            margin: 0;
            padding: 20px 24px;
            max-width: 680px;
        }
        h1 { font-size: 1.5em; margin: 0 0 12px 0; }
        h2 { font-size: 1.1em; margin: 20px 0 6px 0; }
        p { margin: 0 0 8px 0; }
        ul, ol { margin: 0 0 8px 0; padding-left: 1.5em; }
        li { margin-bottom: 3px; }
        code {
            font-family: ui-monospace, monospace;
            font-size: 0.9em;
            background: rgba(0,0,0,0.06);
            padding: 1px 4px;
            border-radius: 3px;
        }
        pre {
            background: rgba(0,0,0,0.06);
            border-radius: 6px;
            padding: 10px 14px;
            overflow-x: auto;
            margin: 0 0 10px 0;
        }
        pre code { background: none; padding: 0; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 10px; }
        th, td { text-align: left; padding: 5px 10px; border-bottom: 1px solid rgba(0,0,0,0.1); }
        th { font-weight: 600; border-bottom: 2px solid rgba(0,0,0,0.15); }
        @media (prefers-color-scheme: dark) {
            body { color: #e8e8e8; }
            code { background: rgba(255,255,255,0.1); }
            pre { background: rgba(255,255,255,0.08); }
            th, td { border-bottom-color: rgba(255,255,255,0.12); }
            th { border-bottom-color: rgba(255,255,255,0.2); }
        }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
