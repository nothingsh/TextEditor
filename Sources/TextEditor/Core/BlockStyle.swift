//
//  BlockStyle.swift
//
//

import UIKit

/// Paragraph-level structure. A paragraph has exactly one block style.
///
/// The style is stored in the `.blockStyle` attribute, never as marker characters in the text,
/// so bullets and numbers can't be edited by accident and serializers see clean content.
public enum BlockStyle: String, CaseIterable, Hashable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case bulletList
    case numberedList
    case quote
    case codeBlock

    public var headingLevel: Int? {
        switch self {
        case .heading1: return 1
        case .heading2: return 2
        case .heading3: return 3
        default: return nil
        }
    }

    public var isList: Bool {
        self == .bulletList || self == .numberedList
    }

    var isHeading: Bool {
        headingLevel != nil
    }

    /// Lists and quotes continue on Return and are removed by Return on an empty line or Delete at its start.
    var continuesOnReturn: Bool {
        isList || self == .quote
    }

    init(headingLevel level: Int) {
        switch level {
        case ...1: self = .heading1
        case 2: self = .heading2
        default: self = .heading3
        }
    }

    /// Leading space reserved for the marker, bar or code background padding.
    var indent: CGFloat {
        switch self {
        case .bulletList, .numberedList: return 24
        case .quote: return 16
        case .codeBlock: return 8
        default: return 0
        }
    }

    /// Headings get breathing room; other blocks stay tight so lists, quotes and code backgrounds read as one unit.
    var spacingBefore: CGFloat {
        isHeading ? 10 : 0
    }

    var spacingAfter: CGFloat {
        isHeading ? 4 : 0
    }

    func headingSize(defaultSize: CGFloat) -> CGFloat {
        switch self {
        case .heading1: return (defaultSize * 1.6).rounded()
        case .heading2: return (defaultSize * 1.35).rounded()
        case .heading3: return (defaultSize * 1.15).rounded()
        default: return defaultSize
        }
    }
}

extension NSAttributedString.Key {
    /// Holds a `BlockStyle` raw value. Plain strings keep the attribute archivable.
    static let blockStyle = NSAttributedString.Key("TextEditor.BlockStyle")
}

extension RichTextFormatter {
    // MARK: Reading Blocks

    static func blockStyle(in attributes: Attributes) -> BlockStyle {
        (attributes[.blockStyle] as? String).flatMap(BlockStyle.init(rawValue:)) ?? .paragraph
    }

    static func blockStyle(of text: NSAttributedString, at location: Int) -> BlockStyle {
        guard location < text.length else {
            return .paragraph
        }
        return blockStyle(in: text.attributes(at: location, effectiveRange: nil))
    }

    /// Ranges of each paragraph in `range`, including its trailing newline.
    static func paragraphRanges(in text: NSAttributedString, range: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        (text.string as NSString).enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosingRange, _ in
            ranges.append(enclosingRange)
        }
        return ranges
    }

    /// The block style shared by every paragraph in `range`, or `nil` when they differ.
    static func commonBlockStyle(in text: NSAttributedString, range: NSRange) -> BlockStyle? {
        let styles = Set(paragraphRanges(in: text, range: range).map { blockStyle(of: text, at: $0.location) })
        return styles.count == 1 ? styles.first : nil
    }

    // MARK: Writing Direction

    /// The direction of the first strongly directional character, or `nil` for text without one,
    /// such as an empty paragraph or one with only digits and punctuation.
    static func writingDirection(of text: String) -> NSWritingDirection? {
        for scalar in text.unicodeScalars {
            if isRightToLeftScript(scalar) {
                return .rightToLeft
            }
            if CharacterSet.letters.contains(scalar) {
                return .leftToRight
            }
        }
        return nil
    }

    /// Hebrew, Arabic, Syriac, Thaana, N'Ko and related blocks, plus their presentation forms.
    private static func isRightToLeftScript(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x10800...0x10FFF, 0x1E800...0x1EFFF:
            return true
        default:
            return false
        }
    }

    /// Which side a paragraph's indent, and so its marker, is on. TextKit indents `.natural` paragraphs
    /// by the system's default direction rather than by their text, so that's the fallback here too.
    static func isRightToLeft(_ attributes: Attributes) -> Bool {
        let direction = (attributes[.paragraphStyle] as? NSParagraphStyle)?.baseWritingDirection ?? .natural
        let resolved = direction == .natural ? NSParagraphStyle.defaultWritingDirection(forLanguage: nil) : direction
        return resolved == .rightToLeft
    }

    // MARK: Writing Blocks

    /// Applies `block` to one paragraph's attributes: the marker, indentation and, for headings and code, the font.
    static func setting(_ block: BlockStyle, in attributes: Attributes, defaultFont: UIFont) -> Attributes {
        var result = attributes
        let previous = blockStyle(in: attributes)
        result[.blockStyle] = block == .paragraph ? nil : block.rawValue

        let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = block.indent
        style.headIndent = block.indent
        style.paragraphSpacingBefore = block.spacingBefore
        style.paragraphSpacing = block.spacingAfter
        result[.paragraphStyle] = style

        let currentFont = font(in: attributes, defaultFont: defaultFont)
        result[.font] = blockFont(for: block, replacing: previous, currentFont: currentFont, defaultFont: defaultFont)
        return result
    }

    /// Headings and code blocks own their font. Leaving one restores the body font, keeping italics.
    static func blockFont(for block: BlockStyle, replacing previous: BlockStyle, currentFont: UIFont, defaultFont: UIFont) -> UIFont {
        let isItalic = currentFont.hasTrait(.traitItalic)
        switch block {
        case .heading1, .heading2, .heading3:
            return defaultFont
                .withSize(block.headingSize(defaultSize: defaultFont.pointSize))
                .withTrait(.traitBold, enabled: true)
                .withTrait(.traitItalic, enabled: isItalic)
        case .codeBlock:
            return .monospacedSystemFont(ofSize: defaultFont.pointSize, weight: .regular)
        default:
            guard previous.isHeading || previous == .codeBlock else {
                return currentFont
            }
            return defaultFont.withTrait(.traitItalic, enabled: isItalic)
        }
    }
}
