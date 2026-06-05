import Foundation

struct MarkdownExtensions: Codable {
    var highlight: Bool = true
    var superscript: Bool = true
    var subscript_: Bool = true  // trailing underscore: `subscript` is a Swift keyword
    var underline: Bool = true
}
