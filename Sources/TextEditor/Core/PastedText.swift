//
//  PastedText.swift
//
//

import UIKit
import UniformTypeIdentifiers

/// Turns pasteboard contents into editor content, and works out how pasted paragraphs join the paragraphs around them.
///
/// Text copied in the editor round-trips losslessly through a private archive type. Text from elsewhere is read
/// as HTML or RTF and rebuilt from the editor's own vocabulary: block styles, inline styles, links, colors and
/// images. Foreign fonts, sizes and paragraph settings are dropped, so pasted text matches the document.
enum PastedText {
    typealias Attributes = RichTextFormatter.Attributes

    /// The editor's own pasteboard type: an archive from ``RichTextSerializer/archivedData(from:)``.
    static let archiveType = "io.github.nothingsh.texteditor.archive"

    // MARK: Writing

    /// Adds the editor's archive, and HTML when UIKit didn't write any, to the first pasteboard item.
    static func addRepresentations(of text: NSAttributedString, to pasteboard: UIPasteboard) {
        guard text.length > 0, let data = try? RichTextSerializer.archivedData(from: text) else {
            return
        }
        var items = pasteboard.items
        if items.isEmpty {
            items = [[:]]
        }
        items[0][archiveType] = data
        if items[0][UTType.html.identifier] == nil {
            items[0][UTType.html.identifier] = RichTextSerializer.html(from: text)
        }
        pasteboard.items = items
    }

    // MARK: Reading

    /// The pasteboard's rich text in the editor's vocabulary, or `nil` when it only has plain text or images,
    /// which UIKit already pastes with the typing attributes.
    static func text(from pasteboard: UIPasteboard, defaultFont: UIFont, textColor: UIColor) -> NSAttributedString? {
        if let data = pasteboard.data(forPasteboardType: archiveType),
           let text = try? RichTextSerializer.attributedString(archivedData: data) {
            return RichTextFormatter.applyingDefaults(to: text, font: defaultFont, textColor: textColor)
        }
        if let html = string(forType: UTType.html.identifier, in: pasteboard) {
            let text = RichTextSerializer.attributedString(html: html, defaultFont: defaultFont, textColor: textColor)
            return text.length > 0 ? droppingNeutralColors(from: text, textColor: textColor) : nil
        }
        let richTextTypes: [(UTType, NSAttributedString.DocumentType)] = [(.flatRTFD, .rtfd), (.rtf, .rtf)]
        for (type, documentType) in richTextTypes {
            guard let data = pasteboard.data(forPasteboardType: type.identifier),
                  let text = try? NSAttributedString(data: data, options: [.documentType: documentType], documentAttributes: nil) else {
                continue
            }
            return normalized(foreign: text, defaultFont: defaultFont, textColor: textColor)
        }
        return nil
    }

    /// HTML is usually stored as a string, but some apps write UTF-8 data.
    private static func string(forType type: String, in pasteboard: UIPasteboard) -> String? {
        if let string = pasteboard.value(forPasteboardType: type) as? String {
            return string
        }
        return pasteboard.data(forPasteboardType: type).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Rebuilds rich text from another app, such as RTF from Notes, Pages or Xcode.
    ///
    /// Fonts are reduced to bold, italic and monospace. A paragraph that's bold and clearly larger than the
    /// body text becomes a heading, one in an `NSTextList` becomes a list item, nested as deep as its lists,
    /// without its marker text,
    /// and one that's entirely monospaced becomes a code line.
    static func normalized(foreign text: NSAttributedString, defaultFont: UIFont, textColor: UIColor) -> NSAttributedString {
        let fullRange = NSRange(location: 0, length: text.length)
        let ranges = RichTextFormatter.paragraphRanges(in: text, range: fullRange)
        var paragraphs = RichTextDocument.paragraphs(of: text, defaultFont: defaultFont, defaultTextColor: textColor)
        let bodySize = predominantFontSize(in: text) ?? defaultFont.pointSize

        for (index, range) in zip(paragraphs.indices, ranges) where range.length > 0 {
            let attributes = text.attributes(at: range.location, effectiveRange: nil)
            let segments = paragraphs[index].segments
            if let lists = (attributes[.paragraphStyle] as? NSParagraphStyle)?.textLists, let list = lists.last {
                paragraphs[index].block = isNumbered(list) ? .numberedList : .bulletList
                paragraphs[index].level = lists.count - 1
                paragraphs[index].segments = removingListMarker(from: segments)
            } else if let level = headingLevel(of: text, in: range, bodySize: bodySize) {
                paragraphs[index].block = BlockStyle(headingLevel: level)
            } else if !segments.isEmpty, segments.allSatisfy({ $0.image == nil && $0.styles.contains(.code) }),
                      segments.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                paragraphs[index].block = .codeBlock
            }
        }
        let rebuilt = NSMutableAttributedString(attributedString: RichTextDocument.build(paragraphs, defaultFont: defaultFont, defaultTextColor: textColor))
        if text.string.hasSuffix("\n"), rebuilt.length > 0 {
            // Copied whole lines end with a newline, which keeps them out of the paragraph they're pasted into.
            let attributes = rebuilt.attributes(at: rebuilt.length - 1, effectiveRange: nil)
            rebuilt.append(NSAttributedString(string: "\n", attributes: attributes))
        }
        return droppingNeutralColors(from: rebuilt, textColor: textColor)
    }

    private static func isNumbered(_ list: NSTextList) -> Bool {
        let format = list.markerFormat.rawValue
        return ["decimal", "roman", "alpha"].contains { format.localizedCaseInsensitiveContains($0) }
    }

    /// Cocoa's RTF reader writes list markers into the text as `"\t•\t"` or `"\t1.\t"`.
    private static func removingListMarker(from segments: [RichTextDocument.Segment]) -> [RichTextDocument.Segment] {
        guard var first = segments.first, first.image == nil,
              let marker = first.text.range(of: #"^\t?[^\t]{1,8}\t"#, options: .regularExpression) else {
            return segments
        }
        first.text.removeSubrange(marker)
        return [first] + segments.dropFirst()
    }

    /// The point size covering the most characters, taken as the body size.
    private static func predominantFontSize(in text: NSAttributedString) -> CGFloat? {
        var counts: [CGFloat: Int] = [:]
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let font = value as? UIFont {
                counts[font.pointSize, default: 0] += range.length
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    private static func headingLevel(of text: NSAttributedString, in range: NSRange, bodySize: CGFloat) -> Int? {
        var smallest = CGFloat.greatestFiniteMagnitude
        var isBold = true
        var hasText = false
        let string = text.string as NSString
        text.enumerateAttribute(.font, in: range) { value, runRange, stop in
            guard !string.substring(with: runRange).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            hasText = true
            guard let font = value as? UIFont, font.hasTrait(.traitBold) else {
                isBold = false
                stop.pointee = true
                return
            }
            smallest = min(smallest, font.pointSize)
        }
        guard hasText, isBold, bodySize > 0 else {
            return nil
        }
        switch smallest / bodySize {
        case 1.45...: return 1
        case 1.25...: return 2
        case 1.1...: return 3
        default: return nil
        }
    }

    /// Black, white and gray are almost always the source's own body color, which would stay black in dark mode.
    /// Real colors are kept.
    static func droppingNeutralColors(from text: NSAttributedString, textColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let color = value as? UIColor, color !== textColor, isNeutral(color) else {
                return
            }
            result.addAttribute(.foregroundColor, value: textColor, range: range)
        }
        return result
    }

    private static func isNeutral(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }
        return max(red, green, blue) - min(red, green, blue) < 0.06
    }

    // MARK: Joining Paragraphs

    /// A character edit that pastes text: replace `range` with `replacement`, then select `selection`.
    struct Edit: Equatable {
        var range: NSRange
        var replacement: NSAttributedString
        var selection: NSRange
    }

    /// How `pasted` replaces `selection` in `text`, with paragraph styles that stay consistent.
    ///
    /// A paragraph has one block style, so where pasted text joins an existing paragraph one side has to win:
    /// - Pasted text that joins the start of the paragraph it lands in takes that paragraph's style,
    ///   as does a single pasted paragraph, so pasting a phrase into a list item keeps it a list item.
    /// - Text after the selection that joins the last pasted paragraph takes the pasted style.
    ///   It's included in the replacement so the whole paste is one ordinary character edit.
    ///
    /// - Parameter destination: The attributes of the paragraph at the start of the selection, or, for an
    ///   empty paragraph, the typing attributes that describe it.
    static func edit(
        pasting pasted: NSAttributedString,
        into text: NSAttributedString,
        selection: NSRange,
        destination: Attributes,
        defaultFont: UIFont
    ) -> Edit {
        let string = text.string as NSString
        let firstParagraph = string.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let selectionEnd = NSMaxRange(selection)
        let lastParagraph = string.paragraphRange(for: NSRange(location: selectionEnd, length: 0))
        var contentEnd = NSMaxRange(lastParagraph)
        while contentEnd > selectionEnd, CharacterSet.newlines.contains(UnicodeScalar(string.character(at: contentEnd - 1)) ?? " ") {
            contentEnd -= 1
        }
        let after = NSRange(location: selectionEnd, length: max(0, contentEnd - selectionEnd))

        let replacement = NSMutableAttributedString(attributedString: pasted)
        let pastedParagraphs = RichTextFormatter.paragraphRanges(in: pasted, range: NSRange(location: 0, length: pasted.length))
        let isSingleParagraph = pastedParagraphs.count <= 1 && !pasted.string.hasSuffix("\n")
        let joinsStart = selection.location > firstParagraph.location

        if let first = pastedParagraphs.first, isSingleParagraph || joinsStart {
            restyle(replacement, range: first, like: destination, defaultFont: defaultFont)
        }

        var range = selection
        if after.length > 0, !pasted.string.hasSuffix("\n"), let last = pastedParagraphs.last {
            let lastAttributes = last.length > 0 ? replacement.attributes(at: last.location, effectiveRange: nil) : destination
            let afterAttributes = text.attributes(at: after.location, effectiveRange: nil)
            if !hasSameParagraphStyle(afterAttributes, lastAttributes) {
                let joined = NSMutableAttributedString(attributedString: text.attributedSubstring(from: after))
                restyle(joined, range: NSRange(location: 0, length: joined.length), like: lastAttributes, defaultFont: defaultFont)
                replacement.append(joined)
                range.length += after.length
            }
        }
        return Edit(range: range, replacement: replacement, selection: NSRange(location: selection.location + pasted.length, length: 0))
    }

    private static func hasSameParagraphStyle(_ lhs: Attributes, _ rhs: Attributes) -> Bool {
        RichTextFormatter.paragraphFormat(in: lhs) == RichTextFormatter.paragraphFormat(in: rhs)
            && alignment(in: lhs) == alignment(in: rhs)
    }

    private static func alignment(in attributes: Attributes) -> NSTextAlignment {
        (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural
    }

    /// Gives `range` the paragraph format (block style, list level and checkbox) and alignment of `paragraph`,
    /// keeping inline styles.
    private static func restyle(_ text: NSMutableAttributedString, range: NSRange, like paragraph: Attributes, defaultFont: UIFont) {
        let format = RichTextFormatter.paragraphFormat(in: paragraph)
        let alignment = alignment(in: paragraph)
        RichTextFormatter.transformAttributes(in: text, range: range) { attributes in
            RichTextFormatter.setting(alignment: alignment, in: RichTextFormatter.setting(format, in: attributes, defaultFont: defaultFont))
        }
    }
}
