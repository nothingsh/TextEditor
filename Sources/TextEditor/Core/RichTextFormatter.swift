//
//  RichTextFormatter.swift
//
//

import UIKit

/// Character styles that can be toggled on and off.
public enum TextStyle: CaseIterable, Hashable {
    /// Bold, keeping the font family.
    case bold
    /// Italic, keeping the font family.
    case italic
    /// A single underline.
    case underline
    /// A single strikethrough line.
    case strikethrough
    /// Inline code, shown in a monospaced font.
    case code
}

/// A snapshot of the formatting at the current selection, used to drive toolbar state.
struct FormattingState: Equatable {
    var activeStyles: Set<TextStyle>
    var fontSize: CGFloat
    var textColor: UIColor
    var alignment: NSTextAlignment
    var blockStyle: BlockStyle
    var link: URL?
}

/// Pure functions that read and write rich text attributes.
/// Nothing here touches a text view, which keeps the formatting rules easy to unit test.
enum RichTextFormatter {
    typealias Attributes = [NSAttributedString.Key: Any]

    static let fontSizeRange: ClosedRange<CGFloat> = 8...72

    // MARK: Reading

    static func isStyle(_ style: TextStyle, activeIn attributes: Attributes, defaultFont: UIFont) -> Bool {
        switch style {
        case .bold:
            return font(in: attributes, defaultFont: defaultFont).hasTrait(.traitBold)
        case .italic:
            return font(in: attributes, defaultFont: defaultFont).hasTrait(.traitItalic)
        case .underline:
            return isLineStyleSet(attributes[.underlineStyle])
        case .strikethrough:
            return isLineStyleSet(attributes[.strikethroughStyle])
        case .code:
            return font(in: attributes, defaultFont: defaultFont).hasTrait(.traitMonoSpace)
        }
    }

    /// A style counts as active only when every character in `range` has it,
    /// so toggling a mixed selection turns the style on for all of it, as Pages and Notes do.
    static func isStyle(_ style: TextStyle, activeIn text: NSAttributedString, range: NSRange, defaultFont: UIFont) -> Bool {
        guard range.length > 0 else {
            return false
        }
        var isActive = true
        text.enumerateAttributes(in: range) { attributes, _, stop in
            if !isStyle(style, activeIn: attributes, defaultFont: defaultFont) {
                isActive = false
                stop.pointee = true
            }
        }
        return isActive
    }

    /// With a caret, formatting comes from the typing attributes; with a selection, from the selected text.
    static func state(
        of text: NSAttributedString,
        selection: NSRange,
        typingAttributes: Attributes,
        defaultFont: UIFont,
        defaultTextColor: UIColor
    ) -> FormattingState {
        let hasSelection = selection.length > 0 && NSMaxRange(selection) <= text.length
        let attributes = hasSelection ? text.attributes(at: selection.location, effectiveRange: nil) : typingAttributes
        let activeStyles = TextStyle.allCases.filter { style in
            hasSelection
                ? isStyle(style, activeIn: text, range: selection, defaultFont: defaultFont)
                : isStyle(style, activeIn: attributes, defaultFont: defaultFont)
        }
        // Block style is a paragraph property: read it from the caret's paragraph, which may be
        // the empty trailing paragraph that only exists in the typing attributes.
        let paragraph = paragraphRange(in: text, for: selection)
        let isEmptyParagraph = (text.string as NSString).substring(with: paragraph).trimmingCharacters(in: .newlines).isEmpty
        let blockStyle = isEmptyParagraph && selection.length == 0
            ? self.blockStyle(in: typingAttributes)
            : commonBlockStyle(in: text, range: paragraph) ?? .paragraph
        return FormattingState(
            activeStyles: Set(activeStyles),
            fontSize: font(in: attributes, defaultFont: defaultFont).pointSize,
            textColor: attributes[.foregroundColor] as? UIColor ?? defaultTextColor,
            alignment: (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural,
            blockStyle: blockStyle,
            link: link(in: text, at: selection)
        )
    }

    /// The link under the caret or at the start of the selection.
    static func link(in text: NSAttributedString, at selection: NSRange) -> URL? {
        let location = selection.length > 0 ? selection.location : selection.location - 1
        guard location >= 0, location < text.length else {
            return nil
        }
        return linkURL(text.attribute(.link, at: location, effectiveRange: nil))
    }

    /// `.link` may hold a `URL` or a `String`.
    static func linkURL(_ value: Any?) -> URL? {
        if let url = value as? URL {
            return url
        }
        return (value as? String).flatMap(URL.init(string:))
    }

    // MARK: Writing Attributes

    static func setting(_ style: TextStyle, enabled: Bool, in attributes: Attributes, defaultFont: UIFont) -> Attributes {
        var result = attributes
        switch style {
        case .bold:
            result[.font] = font(in: attributes, defaultFont: defaultFont).withTrait(.traitBold, enabled: enabled)
        case .italic:
            result[.font] = font(in: attributes, defaultFont: defaultFont).withTrait(.traitItalic, enabled: enabled)
        case .underline:
            result[.underlineStyle] = enabled ? NSUnderlineStyle.single.rawValue : nil
        case .strikethrough:
            result[.strikethroughStyle] = enabled ? NSUnderlineStyle.single.rawValue : nil
        case .code:
            let font = font(in: attributes, defaultFont: defaultFont)
            let isBold = font.hasTrait(.traitBold)
            result[.font] = enabled
                ? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: isBold ? .bold : .regular)
                : defaultFont.withSize(font.pointSize).withTrait(.traitBold, enabled: isBold)
        }
        return result
    }

    /// Shifts the font size by `delta`, clamped to `fontSizeRange`.
    static func adjustingFontSize(by delta: CGFloat, in attributes: Attributes, defaultFont: UIFont) -> Attributes {
        var result = attributes
        let font = font(in: attributes, defaultFont: defaultFont)
        let size = min(max(font.pointSize + delta, fontSizeRange.lowerBound), fontSizeRange.upperBound)
        result[.font] = font.withSize(size)
        return result
    }

    static func setting(textColor: UIColor, in attributes: Attributes) -> Attributes {
        var result = attributes
        result[.foregroundColor] = textColor
        return result
    }

    static func setting(alignment: NSTextAlignment, in attributes: Attributes) -> Attributes {
        var result = attributes
        result[.paragraphStyle] = paragraphStyle(attributes[.paragraphStyle], with: alignment)
        return result
    }

    // MARK: Writing Text

    /// Rewrites every attribute run in `range` with `transform`. Runs keep their own values
    /// for anything `transform` leaves alone, so mixed fonts and sizes survive.
    static func transformAttributes(in text: NSMutableAttributedString, range: NSRange, _ transform: (Attributes) -> Attributes) {
        text.beginEditing()
        text.enumerateAttributes(in: range) { attributes, runRange, _ in
            text.setAttributes(transform(attributes), range: runRange)
        }
        text.endEditing()
    }

    /// The paragraphs touched by `selection`. Alignment always applies to whole paragraphs.
    static func paragraphRange(in text: NSAttributedString, for selection: NSRange) -> NSRange {
        (text.string as NSString).paragraphRange(for: selection)
    }

    /// Sets alignment on every paragraph style in `range`, preserving line spacing and other paragraph settings.
    static func setAlignment(_ alignment: NSTextAlignment, in text: NSMutableAttributedString, range: NSRange) {
        text.beginEditing()
        text.enumerateAttribute(.paragraphStyle, in: range) { value, runRange, _ in
            text.addAttribute(.paragraphStyle, value: paragraphStyle(value, with: alignment), range: runRange)
        }
        text.endEditing()
    }

    /// Fills in a font and color for runs that lack them, so content created elsewhere
    /// renders with the editor's defaults instead of UIKit's 12pt black text.
    static func applyingDefaults(to text: NSAttributedString, font: UIFont, textColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: result.length)
        transformAttributes(in: result, range: fullRange) { attributes in
            var attributes = attributes
            if attributes[.font] == nil {
                attributes[.font] = font
            }
            if attributes[.foregroundColor] == nil {
                attributes[.foregroundColor] = textColor
            }
            return attributes
        }
        return result
    }

    // MARK: Helpers

    static func font(in attributes: Attributes, defaultFont: UIFont) -> UIFont {
        attributes[.font] as? UIFont ?? defaultFont
    }

    private static func isLineStyleSet(_ value: Any?) -> Bool {
        guard let rawValue = value as? Int else {
            return false
        }
        return rawValue != 0
    }

    private static func paragraphStyle(_ value: Any?, with alignment: NSTextAlignment) -> NSParagraphStyle {
        let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.alignment = alignment
        return style
    }
}
