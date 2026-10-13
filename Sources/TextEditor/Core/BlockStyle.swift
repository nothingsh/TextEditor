//
//  BlockStyle.swift
//
//

import UIKit

/// Paragraph-level structure. A paragraph has exactly one block style.
///
/// The style is stored in the `.blockStyle` attribute, never as marker characters in the text,
/// so bullets and numbers can't be edited by accident and serializers see clean content.
///
/// Raw values are stored in archived documents, so they never change.
public enum BlockStyle: String, CaseIterable, Hashable {
    /// Body text.
    case paragraph
    /// The largest heading, shown bold at 1.6 times the body size.
    case heading1
    /// A heading shown bold at 1.35 times the body size.
    case heading2
    /// A heading shown bold at 1.15 times the body size.
    case heading3
    /// A bulleted list item.
    case bulletList
    /// A numbered list item, numbered from 1 within each run of consecutive items at the same level.
    case numberedList
    /// A checklist item with a checkbox in place of a bullet. Tap the checkbox to tick it.
    case checklist
    /// A block quote, marked with a bar at its leading edge.
    case quote
    /// A line of a code block, in a monospaced font on a shaded background.
    case codeBlock

    /// 1, 2 or 3 for headings, `nil` otherwise.
    public var headingLevel: Int? {
        switch self {
        case .heading1: return 1
        case .heading2: return 2
        case .heading3: return 3
        default: return nil
        }
    }

    /// Whether this is a bulleted, numbered or checklist item. List items can be nested.
    public var isList: Bool {
        self == .bulletList || self == .numberedList || self == .checklist
    }

    /// The deepest list level, counted from 0.
    public static let maxListLevel = 5

    /// Extra indent for each level of list nesting.
    static let levelIndent: CGFloat = 24

    var isHeading: Bool {
        headingLevel != nil
    }

    /// Lists and quotes continue on Return and are removed by Return on an empty line or Delete at its start.
    /// Code blocks also continue on Return, but only Delete at a line's start removes them, so blank code lines stay possible.
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
        case .checklist: return 28
        case .quote: return 16
        case .codeBlock: return 8
        default: return 0
        }
    }

    /// The leading indent of a paragraph at `level`; levels only apply to lists.
    func indent(level: Int) -> CGFloat {
        isList ? indent + CGFloat(level) * Self.levelIndent : indent
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

/// Everything a paragraph carries beyond its text: the block style, and for list items their nesting
/// and checkbox. These live in attributes on every character of the paragraph and are read from its first.
struct ParagraphFormat: Equatable {
    var block: BlockStyle
    /// Nesting depth from 0, always 0 for paragraphs that aren't list items.
    var level = 0
    /// Whether a checklist item is ticked, always `false` for other paragraphs.
    var isChecked = false

    init(block: BlockStyle, level: Int = 0, isChecked: Bool = false) {
        self.block = block
        self.level = block.isList ? min(max(level, 0), BlockStyle.maxListLevel) : 0
        self.isChecked = block == .checklist && isChecked
    }

    static let paragraph = ParagraphFormat(block: .paragraph)

    var indent: CGFloat {
        block.indent(level: level)
    }

    /// The same format with `block`, keeping the level between list styles.
    func with(_ block: BlockStyle) -> ParagraphFormat {
        ParagraphFormat(block: block, level: level, isChecked: isChecked)
    }
}

extension NSAttributedString.Key {
    /// Holds a `BlockStyle` raw value. Plain strings keep the attribute archivable.
    static let blockStyle = NSAttributedString.Key("TextEditor.BlockStyle")
    /// A list item's nesting level as an integer; absent at level 0.
    static let listLevel = NSAttributedString.Key("TextEditor.ListLevel")
    /// `true` on a ticked checklist item; absent otherwise.
    static let checklistChecked = NSAttributedString.Key("TextEditor.Checked")
}

/// Numbers list items the way Markdown and HTML nest them. Each level counts its own run of numbered items;
/// a shallower item ends the deeper runs, a different list style at the same level restarts the count,
/// and any other paragraph ends every run.
struct ListNumbering {
    private var runs: [(block: BlockStyle, count: Int)] = []

    /// The ordinal of `format` if it's a numbered item, otherwise 0.
    mutating func next(_ format: ParagraphFormat) -> Int {
        guard format.block.isList else {
            runs = []
            return 0
        }
        let level = format.level
        if runs.count > level + 1 {
            runs.removeLast(runs.count - level - 1)
        }
        while runs.count <= level {
            runs.append((.paragraph, 0))
        }
        runs[level] = runs[level].block == format.block ? (format.block, runs[level].count + 1) : (format.block, 1)
        return format.block == .numberedList ? runs[level].count : 0
    }
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

    static func paragraphFormat(in attributes: Attributes) -> ParagraphFormat {
        ParagraphFormat(
            block: blockStyle(in: attributes),
            level: (attributes[.listLevel] as? Int) ?? 0,
            isChecked: (attributes[.checklistChecked] as? Bool) ?? false
        )
    }

    static func paragraphFormat(of text: NSAttributedString, at location: Int) -> ParagraphFormat {
        guard location < text.length else {
            return .paragraph
        }
        return paragraphFormat(in: text.attributes(at: location, effectiveRange: nil))
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
    /// A list item that stays a list item keeps its level.
    static func setting(_ block: BlockStyle, in attributes: Attributes, defaultFont: UIFont) -> Attributes {
        setting(paragraphFormat(in: attributes).with(block), in: attributes, defaultFont: defaultFont)
    }

    /// Applies a whole paragraph format: block style, list level and checkbox, with matching indentation and font.
    static func setting(_ format: ParagraphFormat, in attributes: Attributes, defaultFont: UIFont) -> Attributes {
        var result = attributes
        let block = format.block
        let previous = blockStyle(in: attributes)
        result[.blockStyle] = block == .paragraph ? nil : block.rawValue
        result[.listLevel] = format.level > 0 ? format.level : nil
        result[.checklistChecked] = format.isChecked ? true : nil

        let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = format.indent
        style.headIndent = format.indent
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
