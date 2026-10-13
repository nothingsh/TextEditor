//
//  HTMLSerialization.swift
//
//

import UIKit

/// Writes semantic HTML: headings, lists, quotes, code, inline styles, links, colors, alignment and images.
/// Font sizes are dropped so the host page's styles stay in charge.
enum HTMLWriter {
    typealias Paragraph = RichTextDocument.Paragraph
    typealias Segment = RichTextDocument.Segment

    static func html(from paragraphs: [Paragraph]) -> String {
        var lines: [String] = []
        var index = 0
        while index < paragraphs.count {
            let paragraph = paragraphs[index]
            switch paragraph.block {
            case .bulletList, .numberedList, .quote, .codeBlock:
                // Consecutive paragraphs of these styles share one container element.
                var group: [Paragraph] = []
                while index < paragraphs.count, paragraphs[index].block == paragraph.block {
                    group.append(paragraphs[index])
                    index += 1
                }
                lines.append(container(for: paragraph.block, group))
                continue
            case .heading1, .heading2, .heading3:
                let tag = "h\(paragraph.block.headingLevel ?? 1)"
                lines.append("<\(tag)\(blockAttributes(paragraph))>\(inlineHTML(paragraph.segments, isHeading: true))</\(tag)>")
            case .paragraph:
                let content = inlineHTML(paragraph.segments, isHeading: false)
                lines.append("<p\(blockAttributes(paragraph))>\(content.isEmpty ? "<br>" : content)</p>")
            }
            index += 1
        }
        return lines.joined(separator: "\n")
    }

    private static func container(for block: BlockStyle, _ group: [Paragraph]) -> String {
        switch block {
        case .codeBlock:
            let code = group.map { escaped($0.segments.map(\.text).joined()) }.joined(separator: "\n")
            return "<pre><code>\(code)</code></pre>"
        case .quote:
            let items = group.map { "<p\(blockAttributes($0))>\(inlineHTML($0.segments, isHeading: false))</p>" }
            return "<blockquote>\n" + items.joined(separator: "\n") + "\n</blockquote>"
        default:
            let tag = block == .numberedList ? "ol" : "ul"
            let items = group.map { "<li\(blockAttributes($0))>\(inlineHTML($0.segments, isHeading: false))</li>" }
            return "<\(tag)>\n" + items.joined(separator: "\n") + "\n</\(tag)>"
        }
    }

    /// `dir="rtl"` for right-to-left text, decided by its first strong character as in the editor,
    /// so lists and quotes keep their markers and indents on the text's side; then any alignment.
    private static func blockAttributes(_ paragraph: Paragraph) -> String {
        let text = paragraph.segments.map(\.text).joined()
        let direction = RichTextFormatter.writingDirection(of: text) == .rightToLeft ? " dir=\"rtl\"" : ""
        return direction + alignmentAttribute(paragraph)
    }

    /// Explicit left alignment is written too: in a right-to-left paragraph it differs from the default.
    private static func alignmentAttribute(_ paragraph: Paragraph) -> String {
        switch paragraph.alignment {
        case .left: return " style=\"text-align: left\""
        case .center: return " style=\"text-align: center\""
        case .right: return " style=\"text-align: right\""
        case .justified: return " style=\"text-align: justify\""
        default: return ""
        }
    }

    static func inlineHTML(_ segments: [Segment], isHeading: Bool) -> String {
        segments.map { segment in
            if let image = segment.image {
                return "<img src=\"\(escaped(ImageAttachments.dataURI(for: image)))\" alt=\"\">"
            }
            var html = escaped(segment.text).replacingOccurrences(of: "\u{2028}", with: "<br>")
            let styles = segment.styles
            if styles.contains(.code) { html = "<code>\(html)</code>" }
            if styles.contains(.strikethrough) { html = "<s>\(html)</s>" }
            if styles.contains(.underline) { html = "<u>\(html)</u>" }
            if styles.contains(.italic) { html = "<em>\(html)</em>" }
            if styles.contains(.bold) && !isHeading { html = "<strong>\(html)</strong>" }
            if let color = segment.color {
                html = "<span style=\"color: \(RichTextDocument.hexString(for: color))\">\(html)</span>"
            }
            if let link = segment.link {
                html = "<a href=\"\(escaped(link.absoluteString))\">\(html)</a>"
            }
            return html
        }
        .joined()
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// A forgiving reader for everyday HTML: unclosed tags, unknown tags and entities are all fine.
/// Unknown tags are skipped but their text is kept; `<script>`, `<style>` and `<head>` contents are dropped.
/// Only `data:` URI images are loaded; remote images are dropped, since they can't be fetched here.
struct HTMLReader {
    typealias Paragraph = RichTextDocument.Paragraph
    typealias Segment = RichTextDocument.Segment

    private struct InlineStyle {
        var tag: String
        var styles: Set<TextStyle> = []
        var link: URL?
        var color: UIColor?
    }

    private var paragraphs: [Paragraph] = []
    private var segments: [Segment] = []
    private var inlineStack: [InlineStyle] = []
    private var listStack: [BlockStyle] = []
    private var quoteDepth = 0
    private var headingLevel: Int?
    private var isInPre = false
    private var alignment: NSTextAlignment = .natural
    private var skippedTag: String?

    static func paragraphs(from html: String) -> [Paragraph] {
        var reader = HTMLReader()
        reader.read(html)
        return reader.paragraphs
    }

    // MARK: Tokenizing

    private mutating func read(_ html: String) {
        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<" {
                if html[index...].hasPrefix("<!--") {
                    let end = html.range(of: "-->", range: index..<html.endIndex)?.upperBound ?? html.endIndex
                    index = end
                    continue
                }
                if let close = html[index...].firstIndex(of: ">") {
                    handleTag(String(html[html.index(after: index)..<close]))
                    index = html.index(after: close)
                    continue
                }
            }
            let next = html[index...].firstIndex(of: "<") ?? html.endIndex
            let end = next == index ? html.index(after: index) : next
            handleText(String(html[index..<end]))
            index = end
        }
        flushParagraph()
    }

    private mutating func handleTag(_ source: String) {
        let isClosing = source.hasPrefix("/")
        let body = isClosing ? String(source.dropFirst()) : source
        let name = String(body.prefix(while: { !$0.isWhitespace && $0 != "/" })).lowercased()
        let attributes = Self.attributes(in: body)

        if let skippedTag {
            if isClosing && name == skippedTag {
                self.skippedTag = nil
            }
            return
        }
        if !isClosing && (name == "script" || name == "style" || name == "head") {
            skippedTag = name
            return
        }
        isClosing ? closeTag(name) : openTag(name, attributes: attributes)
    }

    private mutating func openTag(_ name: String, attributes: [String: String]) {
        switch name {
        case "p", "div", "li", "h1", "h2", "h3", "h4", "h5", "h6", "tr":
            flushParagraph()
            if name.hasPrefix("h"), let level = Int(name.dropFirst()) {
                headingLevel = level
            }
            alignment = Self.alignment(from: attributes["style"])
        case "ul", "ol":
            flushParagraph()
            listStack.append(name == "ol" ? .numberedList : .bulletList)
        case "blockquote":
            flushParagraph()
            quoteDepth += 1
        case "pre":
            flushParagraph()
            isInPre = true
        case "br":
            if isInPre {
                appendText("\n")
            } else {
                appendText("\u{2028}")
            }
        case "img":
            if let source = attributes["src"], let image = ImageAttachments.payload(fromDataURI: source) {
                segments.append(Segment(text: "", image: image))
            }
        case "strong", "b", "em", "i", "u", "ins", "s", "strike", "del", "code", "span", "font":
            inlineStack.append(inlineStyle(for: name, attributes: attributes))
        case "a":
            let link = attributes["href"].flatMap(URL.init(string:)).flatMap { RichTextDocument.isSafeLink($0) ? $0 : nil }
            inlineStack.append(InlineStyle(tag: name, link: link))
        default:
            break
        }
    }

    private mutating func closeTag(_ name: String) {
        switch name {
        case "p", "div", "li", "tr":
            flushParagraph()
        case "h1", "h2", "h3", "h4", "h5", "h6":
            flushParagraph()
            headingLevel = nil
        case "ul", "ol":
            flushParagraph()
            _ = listStack.popLast()
        case "blockquote":
            flushParagraph()
            quoteDepth = max(0, quoteDepth - 1)
        case "pre":
            flushParagraph()
            isInPre = false
        default:
            if let index = inlineStack.lastIndex(where: { $0.tag == name }) {
                inlineStack.remove(at: index)
            }
        }
    }

    // MARK: Text

    private mutating func handleText(_ raw: String) {
        guard skippedTag == nil else {
            return
        }
        var text = Self.decodingEntities(raw)
        if !isInPre {
            text = text.replacingOccurrences(of: "[ \\t\\r\\n]+", with: " ", options: .regularExpression)
            // Collapse across segment boundaries and drop leading space in a paragraph.
            let previous = segments.last?.text.last
            if text.hasPrefix(" ") && (previous == nil || previous == " " || previous == "\u{2028}") {
                text.removeFirst()
            }
        }
        appendText(text)
    }

    private mutating func appendText(_ text: String) {
        guard !text.isEmpty else {
            return
        }
        let segment = Segment(
            text: text,
            styles: inlineStack.reduce(into: []) { $0.formUnion($1.styles) },
            link: inlineStack.last(where: { $0.link != nil })?.link,
            color: inlineStack.last(where: { $0.color != nil })?.color
        )
        if let last = segments.last, last.hasSameStyle(as: segment) {
            segments[segments.count - 1].text += text
        } else {
            segments.append(segment)
        }
    }

    private mutating func flushParagraph() {
        defer {
            segments = []
            alignment = .natural
        }
        if !isInPre, let last = segments.indices.last {
            // Trailing whitespace before a block boundary is insignificant.
            while segments[last].text.hasSuffix(" ") {
                segments[last].text.removeLast()
            }
        }
        let hasContent = segments.contains { $0.image != nil || !$0.text.isEmpty }
        guard hasContent else {
            return
        }

        if isInPre {
            let lines = segments.map(\.text).joined().components(separatedBy: "\n")
            let trimmed = lines.last == "" ? Array(lines.dropLast()) : lines
            for line in trimmed {
                paragraphs.append(Paragraph(block: .codeBlock, alignment: .natural, segments: [Segment(text: line)]))
            }
            return
        }

        let block: BlockStyle
        if let headingLevel {
            block = BlockStyle(headingLevel: headingLevel)
        } else if let list = listStack.last {
            block = list
        } else if quoteDepth > 0 {
            block = .quote
        } else {
            block = .paragraph
        }
        paragraphs.append(Paragraph(block: block, alignment: alignment, segments: segments))
    }

    /// The tag's own style, adjusted by its inline CSS. Pasted HTML often styles with CSS alone, and
    /// Google Docs wraps whole documents in `<b style="font-weight:normal">`, which mustn't turn them bold.
    private func inlineStyle(for name: String, attributes: [String: String]) -> InlineStyle {
        var styles: Set<TextStyle> = []
        switch name {
        case "strong", "b": styles.insert(.bold)
        case "em", "i": styles.insert(.italic)
        case "u", "ins": styles.insert(.underline)
        case "s", "strike", "del": styles.insert(.strikethrough)
        case "code" where !isInPre: styles.insert(.code)
        default: break
        }
        let css = attributes["style"]
        if let weight = Self.styleValue("font-weight", in: css)?.lowercased() {
            if weight == "bold" || weight == "bolder" || (Int(weight) ?? 0) >= 600 {
                styles.insert(.bold)
            } else {
                styles.remove(.bold)
            }
        }
        if let fontStyle = Self.styleValue("font-style", in: css)?.lowercased() {
            if fontStyle == "italic" || fontStyle == "oblique" {
                styles.insert(.italic)
            } else {
                styles.remove(.italic)
            }
        }
        let decoration = [Self.styleValue("text-decoration", in: css), Self.styleValue("text-decoration-line", in: css)]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if decoration.contains("underline") {
            styles.insert(.underline)
        }
        if decoration.contains("line-through") {
            styles.insert(.strikethrough)
        }
        let color = Self.color(fromStyle: css) ?? attributes["color"].flatMap(Self.color(fromValue:))
        return InlineStyle(tag: name, styles: styles, color: color)
    }

    // MARK: Parsing Helpers

    private static func attributes(in tag: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }
        let range = NSRange(tag.startIndex..., in: tag)
        for match in regex.matches(in: tag, range: range) {
            guard let nameRange = Range(match.range(at: 1), in: tag) else {
                continue
            }
            let value = (2...4).lazy.compactMap { Range(match.range(at: $0), in: tag) }.first.map { String(tag[$0]) } ?? ""
            result[tag[nameRange].lowercased()] = decodingEntities(value)
        }
        return result
    }

    private static func styleValue(_ property: String, in style: String?) -> String? {
        style?.split(separator: ";").lazy.compactMap { declaration -> String? in
            let parts = declaration.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 && parts[0].lowercased() == property ? parts[1] : nil
        }.first
    }

    private static func alignment(from style: String?) -> NSTextAlignment {
        switch styleValue("text-align", in: style)?.lowercased() {
        case "center": return .center
        case "right": return .right
        case "justify": return .justified
        case "left": return .left
        default: return .natural
        }
    }

    private static func color(fromStyle style: String?) -> UIColor? {
        styleValue("color", in: style).flatMap(color(fromValue:))
    }

    /// Supports `#rgb`, `#rrggbb` and `rgb(r, g, b)`.
    static func color(fromValue value: String) -> UIColor? {
        let value = value.trimmingCharacters(in: .whitespaces).lowercased()
        if value.hasPrefix("#") {
            var hex = String(value.dropFirst())
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            guard hex.count == 6, let number = UInt32(hex, radix: 16) else {
                return nil
            }
            return UIColor(hex: number)
        }
        if value.hasPrefix("rgb") {
            let numbers = value.split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
            guard numbers.count >= 3 else {
                return nil
            }
            return UIColor(red: numbers[0] / 255, green: numbers[1] / 255, blue: numbers[2] / 255, alpha: 1)
        }
        return nil
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "mdash": "—", "ndash": "–", "hellip": "…", "copy": "©", "reg": "®", "trade": "™",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "middot": "·", "bull": "•",
    ]

    static func decodingEntities(_ text: String) -> String {
        guard text.contains("&") else {
            return text
        }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "&", let semicolon = text[index...].prefix(12).firstIndex(of: ";") {
                let name = String(text[text.index(after: index)..<semicolon])
                var decoded: String?
                if name.hasPrefix("#x") || name.hasPrefix("#X") {
                    decoded = UInt32(name.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map { String(Character($0)) }
                } else if name.hasPrefix("#") {
                    decoded = UInt32(name.dropFirst()).flatMap(UnicodeScalar.init).map { String(Character($0)) }
                } else {
                    decoded = namedEntities[name]
                }
                if let decoded {
                    result += decoded
                    index = text.index(after: semicolon)
                    continue
                }
            }
            result.append(text[index])
            index = text.index(after: index)
        }
        return result
    }
}
