# markdownViewr

A fast, beautiful markdown viewer for macOS. Open any markdown file — it live-reloads as you edit in your favorite editor.

[![Download](https://img.shields.io/badge/Download-macOS-blue?style=flat-square&logo=apple)](https://github.com/darinkelkhoff/markdownViewr/releases/latest/download/markdownViewr.dmg)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-lightgrey?style=flat-square)
![Free](https://img.shields.io/badge/price-free-brightgreen?style=flat-square)

![markdownViewr screenshot](docs/screenshot.png)

## Download

**[Download for Mac](https://github.com/darinkelkhoff/markdownViewr/releases/latest/download/markdownViewr.dmg)** — macOS 13 Ventura or later, free.

Open the DMG, drag markdownViewr to Applications, and you're done.

Or install via Homebrew:

```bash
brew install --cask darinkelkhoff/tap/markdownviewr
```

## Features

- **GitHub Flavored Markdown** — tables, task lists, strikethrough, fenced code blocks
- **Themed code blocks** — monospaced, with configurable code font and size
- **Fully customizable themes** — built-in theme editor, unlimited user themes, custom CSS
- **Table of contents** — toggleable, resizable, depth picker, depth markers, jump-to-heading
- **Markdown source view** — side-by-side raw source, find across both panes, heading scroll-sync, collapse mirroring
- **Collapsible headings** — click a heading to collapse its section, ⌥-click to anchor to it
- **Live file watching** — re-renders on every save, scroll position preserved
- **Vim navigation keys** — `j`/`k`, `Ctrl+d`/`u`, `gg`/`G`, `]]`/`[[`
- **Find in document** — with match count and vim-style `/`, `n`, `N`
- **YAML frontmatter** — hide, show as a metadata table, or render as Markdown
- **Open in external editor** — configure any editor or app, one click from the toolbar
- **Automatic updates** — stays current via Sparkle

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `j` / `k` | Scroll down / up |
| `Ctrl+d` / `Ctrl+u` | Half page down / up |
| `gg` / `G` | Top / bottom of document |
| `]]` / `[[` | Next / previous heading |
| `⌘F` | Find |
| `/` | Focus find bar (vim-style) |
| `n` / `N` | Next / previous match |
| `⌘⇧↓` / `⌘⇧↑` | Next / previous theme |

## Building from Source

Requires Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and [just](https://github.com/casey/just).

```bash
git clone https://github.com/darinkelkhoff/markdownViewr.git
cd markdownViewr
just run
```

`just --list` shows all available recipes.
