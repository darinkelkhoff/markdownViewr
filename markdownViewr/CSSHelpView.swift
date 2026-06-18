import SwiftUI

struct CSSHelpView: View {
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSS Reference")
                .font(.headline)

            Group {
                Text("Structure")
                    .font(.subheadline).bold()
                codeBlock("""
                body
                  div#content
                    div.frontmatter > table > tr
                      > td.fm-key, td.fm-value
                    h1, h2, h3, h4, h5, h6
                      > span.collapse-arrow
                    h1.collapsed, h2.collapsed, ...
                    p, ul, ol, blockquote, hr
                    pre > code
                    table > thead/tbody > tr > th/td
                    img
                """)
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
                #raw-source              (the pane)
                #raw-source pre, code    (the text)
                #raw-source .raw-h       (heading lines)
                #raw-source .raw-ellipsis (collapsed marker)
                #toc-resizer, #raw-resizer (dividers)
                """)
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
                /* Remove heading underlines */
                h1, h2 { border-bottom: none; }

                /* Custom link hover */
                a:hover { color: var(--h1); }

                /* Rounded images */
                img { border-radius: 12px; }

                /* Color the Markdown source pane */
                #raw-source { background: var(--code-bg); }
                #raw-source pre { color: var(--code-text); }
                #raw-source .raw-h { color: var(--h2); }

                /* Style the table of contents */
                #toc a.active { color: var(--h1); }
                #toc { background: var(--code-bg); }
                """)
            }
        }
        .font(.caption)
        .textSelection(.enabled)
        .padding(16)
        }
        .frame(width: 360, height: 520)
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
