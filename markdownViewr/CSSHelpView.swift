import SwiftUI

struct CSSHelpView: View {
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom CSS Guide")
                .font(.headline)

            Group {
                Text("How custom CSS works")
                    .font(.subheadline).bold()
                Text("Custom CSS is injected after markdownViewr's base styles and theme variables. Use it for small overrides, per-theme polish, or global app-wide styling that the theme editor does not expose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                codeBlock("""
                /* Theme variables are available everywhere */
                h1 { color: var(--h1); }
                a:hover { color: var(--link); }
                """)
            }

            Group {
                Text("Document structure")
                    .font(.subheadline).bold()
                codeBlock("""
                body
                  nav#toc
                    a
                    a.active
                    a.toc-h1 .. a.toc-h6
                  div#toc-resizer
                  div#content
                    div#content-inner
                      div.frontmatter > table > tr
                        > td.fm-key, td.fm-value
                      h1, h2, h3, h4, h5, h6
                        > span.collapse-arrow
                      h1.collapsed, h2.collapsed, ...
                      p, ul, ol, blockquote, hr
                      pre > code
                      table > thead/tbody > tr > th/td
                      img
                  div#raw-resizer
                  div#raw-source
                    pre > code
                    .raw-h, .raw-ellipsis
                """)
                Text("#content, #toc, and #raw-source are sibling scrollable panes. #content-inner is the centered rendered document body and is the safer target for width, padding, and document-background changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                Text("Code Blocks")
                    .font(.subheadline).bold()
                Text("Fenced code blocks get a language class:")
                    .font(.caption)
                codeBlock("pre code.language-swift { ... }")
            }

            Group {
                Text("Source Pane")
                    .font(.subheadline).bold()
                Text("The Markdown source view (toolbar toggle):")
                    .font(.caption)
                codeBlock("""
                #raw-source            (the whole pane)
                #raw-source pre        (the source block)
                #raw-source code       (the source text)
                #raw-source .raw-h     (heading lines)
                #raw-source .raw-ellipsis (collapsed marker)
                #toc-resizer, #raw-resizer (dividers)
                """)
                Text("Text color/background live on pre and code — style those, not just #raw-source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                Text("Table of Contents")
                    .font(.subheadline).bold()
                codeBlock("""
                #toc                   (the panel)
                #toc a                 (entries)
                #toc a.active          (current entry)
                #toc .toc-h1 .. .toc-h6 (by level)
                #toc.bullets .toc-h2::before (markers)
                """)
            }

            Group {
                Text("Scrollbars")
                    .font(.subheadline).bold()
                Text("markdownViewr uses WebKit scrollbar pseudo-elements. Style all panes globally, or scope selectors to one scrollable area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                codeBlock("""
                /* All scrollbars */
                ::-webkit-scrollbar { width: 12px; height: 12px; }
                ::-webkit-scrollbar-track { background: var(--bg); }
                ::-webkit-scrollbar-thumb { background: var(--text); }
                ::-webkit-scrollbar-thumb:hover { background: var(--link); }
                ::-webkit-scrollbar-corner { background: var(--bg); }

                /* Rendered document only */
                #content::-webkit-scrollbar-thumb { ... }

                /* Markdown source pane only */
                #raw-source::-webkit-scrollbar-thumb { ... }

                /* Table of contents only */
                #toc::-webkit-scrollbar-thumb { ... }
                """)
                Text("Use #content for the rendered document scrollbar, not #content-inner. The inner element does not scroll.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                Text("CSS Variables")
                    .font(.subheadline).bold()
                Text("You can reference theme variables:")
                    .font(.caption)
                codeBlock("""
                var(--bg)  var(--text)  var(--link)
                var(--h1) .. var(--h6)
                var(--code-bg)  var(--code-text)
                var(--blockquote-border)
                var(--blockquote-bg)
                var(--body-font)  var(--heading-font)
                var(--code-font)
                var(--base-font-size)
                var(--h1-size) .. var(--h6-size)
                var(--code-font-size)  var(--line-height)
                var(--zoom)
                """)
            }

            Group {
                Text("Examples")
                    .font(.subheadline).bold()
                codeBlock("""
                /* Add heading underlines */
                h1, h2 {
                    border-bottom: 1px solid color-mix(in srgb, var(--text) 20%, transparent);
                    padding-bottom: 0.25em;
                }

                /* Custom link hover */
                a:hover { color: var(--h1); }

                /* Rounded images */
                img { border-radius: 12px; }

                /* Recolor the Markdown source pane */
                #raw-source, #raw-source pre,
                #raw-source code { background: var(--code-bg); }
                #raw-source code { color: var(--code-text); }
                #raw-source .raw-h { color: var(--h2); }

                /* Style the table of contents */
                #toc a.active { color: var(--h1); }
                #toc { background: var(--code-bg); }

                /* Soft themed scrollbar thumbs */
                ::-webkit-scrollbar-thumb {
                    background: color-mix(in srgb, var(--text) 30%, var(--bg));
                    border: 3px solid var(--bg);
                    border-radius: 999px;
                }

                /* Make only the source scrollbar louder */
                #raw-source::-webkit-scrollbar-thumb {
                    background: var(--link);
                }
                """)
            }
        }
        .font(.caption)
        .textSelection(.enabled)
        .padding(16)
        }
        .frame(width: 460, height: 640)
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption2, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary)
            .cornerRadius(6)
    }
}
