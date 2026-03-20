import Foundation

let sampleMarkdown = """
# Project Title

A brief description of what this project does and who it's for.

## Installation

```bash
$ brew install markdownviewr
$ markdownviewr --version
```

## Features

- Beautiful **markdown rendering** with customizable themes
- Support for *italic*, **bold**, and ~~strikethrough~~ text
- [Hyperlinks](https://example.com) styled to your palette
- Inline `code spans` and fenced code blocks

### Code Example

```swift
struct Theme: Codable {
    var name: String
    var colors: ThemeColors
    var customCSS: String
}
```

## Blockquotes

> "The best way to predict the future is to invent it."
> — Alan Kay

> Nested blockquotes work too:
>
> > This is a nested quote with some extra context.

## Lists

### Unordered

- First item
  - Nested item A
  - Nested item B
- Second item
- Third item

### Ordered

1. Step one
2. Step two
3. Step three

## Table

| Feature | Status | Notes |
|---------|--------|-------|
| Themes | Done | 6 built-in palettes |
| File watching | Done | Auto-reload on save |
| Editor integration | Done | Configurable apps |
| Custom CSS | Done | Per-theme overrides |

## Horizontal Rule

---

## Headings

### H3 Heading
#### H4 Heading
##### H5 Heading
###### H6 Heading

## Images

Images scale to fit:

![Placeholder](https://placehold.co/600x200/333/ccc?text=Preview+Image)

## Final Notes

This is a **kitchen-sink sample** showing all common Markdown elements so you can see how your theme looks across different content types.
"""
