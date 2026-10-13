//
//  RichTextDocument.swift
//
//

import UIKit

/// Shared plumbing for the serializers: reading an attributed string as paragraphs of styled segments,
/// and building one back from the same shape.
enum RichTextDocument {
    struct Paragraph {
        var block: BlockStyle
        var alignment: NSTextAlignment
        var segments: [Segment]
    }

    /// A run of text with uniform styling, or a single image.
    struct Segment {
        var text: String
        var styles: Set<TextStyle> = []
        var link: URL?
        var color: UIColor?
        var image: ImagePayload?

        func hasSameStyle(as other: Segment) -> Bool {
            styles == other.styles && link == other.link && color == other.color && image == nil && other.image == nil
        }
    }

    // MARK: Reading

    static func paragraphs(of text: NSAttributedString, defaultFont: UIFont, defaultTextColor: UIColor) -> [Paragraph] {
        let fullRange = NSRange(location: 0, length: text.length)
        return RichTextFormatter.paragraphRanges(in: text, range: fullRange).map { range -> Paragraph in
            let content = contentRange(of: range, in: text)
            let attributes = range.length > 0 ? text.attributes(at: range.location, effectiveRange: nil) : [:]
            return Paragraph(
                block: RichTextFormatter.blockStyle(in: attributes),
                alignment: (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural,
                segments: segments(of: text, in: content, defaultFont: defaultFont, defaultTextColor: defaultTextColor)
            )
        }
    }

    /// The paragraph without its trailing newline.
    private static func contentRange(of paragraph: NSRange, in text: NSAttributedString) -> NSRange {
        let string = text.string as NSString
        var length = paragraph.length
        while length > 0, let scalar = UnicodeScalar(string.character(at: paragraph.location + length - 1)),
              CharacterSet.newlines.contains(scalar), scalar != "\u{2028}" {
            length -= 1
        }
        return NSRange(location: paragraph.location, length: length)
    }

    private static func segments(of text: NSAttributedString, in range: NSRange, defaultFont: UIFont, defaultTextColor: UIColor) -> [Segment] {
        var segments: [Segment] = []
        text.enumerateAttributes(in: range) { attributes, runRange, _ in
            if let attachment = attributes[.attachment] as? NSTextAttachment {
                if let payload = ImageAttachments.payload(of: attachment) {
                    segments.append(Segment(text: "", image: payload))
                }
                return
            }
            let color = attributes[.foregroundColor] as? UIColor
            let segment = Segment(
                text: (text.string as NSString).substring(with: runRange),
                styles: Set(TextStyle.allCases.filter { RichTextFormatter.isStyle($0, activeIn: attributes, defaultFont: defaultFont) }),
                link: RichTextFormatter.linkURL(attributes[.link]).flatMap { isSafeLink($0) ? $0 : nil },
                color: color == nil || color!.isEqual(defaultTextColor) ? nil : color
            )
            // Runs often split on attributes the formats can't express, so merge equal neighbours.
            if let last = segments.last, last.hasSameStyle(as: segment) {
                segments[segments.count - 1].text += segment.text
            } else {
                segments.append(segment)
            }
        }
        return segments
    }

    // MARK: Building

    static func build(_ paragraphs: [Paragraph], defaultFont: UIFont, defaultTextColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttributes: RichTextFormatter.Attributes = [.font: defaultFont, .foregroundColor: defaultTextColor]
        var previousParagraphAttributes: RichTextFormatter.Attributes?

        for paragraph in paragraphs {
            var paragraphAttributes = RichTextFormatter.setting(paragraph.block, in: baseAttributes, defaultFont: defaultFont)
            if paragraph.alignment != .natural {
                paragraphAttributes = RichTextFormatter.setting(alignment: paragraph.alignment, in: paragraphAttributes)
            }
            // The newline belongs to the paragraph it ends.
            if let previousParagraphAttributes {
                result.append(NSAttributedString(string: "\n", attributes: previousParagraphAttributes))
            }
            previousParagraphAttributes = paragraphAttributes

            for segment in paragraph.segments {
                var attributes = paragraphAttributes
                for style in segment.styles where !(paragraph.block == .codeBlock && style == .code) {
                    attributes = RichTextFormatter.setting(style, enabled: true, in: attributes, defaultFont: defaultFont)
                }
                attributes[.link] = segment.link
                if let color = segment.color {
                    attributes[.foregroundColor] = color
                }
                if let payload = segment.image {
                    guard let imageAttachment = ImageAttachments.attachment(for: payload) else {
                        continue
                    }
                    let attachment = NSMutableAttributedString(attributedString: NSAttributedString(attachment: imageAttachment))
                    attachment.addAttributes(attributes, range: NSRange(location: 0, length: attachment.length))
                    result.append(attachment)
                } else {
                    result.append(NSAttributedString(string: segment.text, attributes: attributes))
                }
            }
        }
        return result
    }

    // MARK: Helpers

    /// Ordinal of each numbered list item, 1-based within each run of consecutive items.
    static func ordinals(of paragraphs: [Paragraph]) -> [Int] {
        var ordinals: [Int] = []
        var current = 0
        for (index, paragraph) in paragraphs.enumerated() {
            let continues = index > 0 && paragraphs[index - 1].block == .numberedList
            current = paragraph.block == .numberedList ? (continues ? current + 1 : 1) : 0
            ordinals.append(current)
        }
        return ordinals
    }

    /// Schemes that are safe to store and export. Anything else, notably `javascript:` and `data:`,
    /// could run script once exported HTML is shown on a web page.
    private static let safeLinkSchemes: Set<String> = ["http", "https", "mailto", "tel"]

    /// Relative links have no scheme and are allowed.
    static func isSafeLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return true
        }
        return safeLinkSchemes.contains(scheme)
    }

    static func hexString(for color: UIColor) -> String {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let components = [red, green, blue].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", components[0], components[1], components[2])
    }
}
