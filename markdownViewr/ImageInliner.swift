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
