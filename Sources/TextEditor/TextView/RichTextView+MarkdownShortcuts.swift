//
//  RichTextView+MarkdownShortcuts.swift
//
//

import UIKit

/// Markdown typed in a plain paragraph turns into formatting as you go:
/// `# `, `- `, `1. `, `> ` and ```` ``` ```` at the start of a paragraph, and `**bold**`, `*italic*`,
/// `` `code` `` and `~~strikethrough~~` once their closing marker is typed.
///
/// Each conversion is a single undo step that brings back the literal Markdown.
extension RichTextView {
    private struct InlineShortcut {
        let style: TextStyle
        let regex: NSRegularExpression

        /// Matches a complete span ending at the caret; the content may not contain the marker character.
        init(_ style: TextStyle, _ pattern: String) {
            self.style = style
            self.regex = try! NSRegularExpression(pattern: pattern + "$")
        }
    }

    /// Ordered so `**bold**` is tried before `*italic*`.
    private static let inlineShortcuts: [InlineShortcut] = [
        InlineShortcut(.bold, #"(?<!\*)\*\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*\*"#),
        InlineShortcut(.bold, #"(?<![_\w])__(?=[^\s_])([^_]+?)(?<=[^\s_])__"#),
        InlineShortcut(.strikethrough, #"(?<!~)~~(?=[^\s~])([^~]+?)(?<=[^\s~])~~"#),
        InlineShortcut(.italic, #"(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*"#),
        InlineShortcut(.italic, #"(?<![_\w])_(?=[^\s_])([^_]+?)(?<=[^\s_])_"#),
        InlineShortcut(.code, #"(?<!`)`([^`]+)`"#),
    ]

    private static let inlineClosingMarkers: Set<String> = ["*", "_", "~", "`"]

    static func blockStyle(forShortcut prefix: String) -> BlockStyle? {
        switch prefix {
        case "#": return .heading1
        case "##": return .heading2
        case "###": return .heading3
        case "-", "*", "+": return .bulletList
        case ">": return .quote
        case "```": return .codeBlock
        default:
            let number = prefix.dropLast()
            let isOrdinal = (prefix.hasSuffix(".") || prefix.hasSuffix(")")) && !number.isEmpty && number.allSatisfy(\.isNumber)
            return isOrdinal ? .numberedList : nil
        }
    }

    /// Handles `text` as a shortcut if it completes one. Returns `false` to let normal typing proceed.
    func applyMarkdownShortcut(typing text: String) -> Bool {
        guard isMarkdownShortcutsEnabled, markedTextRange == nil, selectedRange.length == 0 else {
            return false
        }
        if text == " " {
            return applyBlockShortcut()
        }
        if Self.inlineClosingMarkers.contains(text) {
            return applyInlineShortcut(closingWith: text)
        }
        return false
    }

    private func applyBlockShortcut() -> Bool {
        guard caretBlockStyle == .paragraph else {
            return false
        }
        let caret = selectedRange.location
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        let prefixRange = NSRange(location: paragraph.location, length: caret - paragraph.location)
        let prefix = (textStorage.string as NSString).substring(with: prefixRange)
        guard let block = Self.blockStyle(forShortcut: prefix) else {
            return false
        }

        // Type the space for real so undo brings back exactly what was typed.
        super.insertText(" ")
        let markerRange = NSRange(location: paragraph.location, length: prefixRange.length + 1)
        performAsOneUndoStep(actionName: "Paragraph Style") {
            replace(markerRange, with: NSAttributedString(), selecting: NSRange(location: paragraph.location, length: 0), actionName: "Paragraph Style")
            setBlockStyle(block)
        }
        return true
    }

    private func applyInlineShortcut(closingWith marker: String) -> Bool {
        guard caretBlockStyle != .codeBlock else {
            return false
        }
        let caret = selectedRange.location
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        let typed = (textStorage.string as NSString).substring(with: NSRange(location: paragraph.location, length: caret - paragraph.location)) + marker
        let searchRange = NSRange(location: 0, length: (typed as NSString).length)

        for shortcut in Self.inlineShortcuts {
            guard let match = shortcut.regex.firstMatch(in: typed, range: searchRange) else {
                continue
            }
            super.insertText(marker)

            let spanRange = NSRange(location: paragraph.location + match.range.location, length: match.range.length)
            let contentRange = NSRange(location: paragraph.location + match.range(at: 1).location, length: match.range(at: 1).length)
            let content = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: contentRange))
            RichTextFormatter.transformAttributes(in: content, range: NSRange(location: 0, length: content.length)) { attributes in
                RichTextFormatter.setting(shortcut.style, enabled: true, in: attributes, defaultFont: defaultFont)
            }
            let caretAfter = NSRange(location: spanRange.location + content.length, length: 0)
            replace(spanRange, with: content, selecting: caretAfter, actionName: "Format")

            // Text typed after the span is plain again.
            typingAttributes = RichTextFormatter.setting(shortcut.style, enabled: false, in: typingAttributes, defaultFont: defaultFont)
            restoreTypingBlockStyle()
            context?.refresh()
            return true
        }
        return false
    }

    private func performAsOneUndoStep(actionName: String, _ changes: () -> Void) {
        let undoManager = undoManager
        undoManager?.beginUndoGrouping()
        changes()
        undoManager?.setActionName(actionName)
        undoManager?.endUndoGrouping()
    }
}
