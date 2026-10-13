//
//  RichTextView+Blocks.swift
//
//

import UIKit

extension RichTextView {
    // MARK: Block Commands

    /// Applies `block` to every paragraph the selection touches.
    func setBlockStyle(_ block: BlockStyle) {
        typingAttributes = RichTextFormatter.setting(block, in: typingAttributes, defaultFont: defaultFont)
        if selectedRange.length == 0 && isCaretInEmptyParagraph {
            pendingBlockStyle = (selectedRange.location, block)
        }
        let range = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        guard range.length > 0 else {
            // An empty trailing paragraph only exists in the typing attributes.
            setNeedsBlockDecorations()
            context?.refresh()
            return
        }
        editAttributes(in: range, actionName: "Paragraph Style") { text, range in
            RichTextFormatter.transformAttributes(in: text, range: range) { attributes in
                RichTextFormatter.setting(block, in: attributes, defaultFont: defaultFont)
            }
        }
    }

    /// Turns `block` on, or back into plain paragraphs when the whole selection already has it.
    func toggleBlockStyle(_ block: BlockStyle) {
        setBlockStyle(currentBlockStyle == block ? .paragraph : block)
    }

    var currentBlockStyle: BlockStyle {
        formattingState.blockStyle
    }

    // MARK: Typing

    /// Return on an empty list item or quote ends the list instead of adding another empty item,
    /// and a new paragraph after a heading starts as body text.
    override func insertText(_ text: String) {
        restoreTypingBlockStyle()
        if applyMarkdownShortcut(typing: text) {
            return
        }
        guard text == "\n", markedTextRange == nil, selectedRange.length == 0 else {
            super.insertText(text)
            restoreTypingBlockStyle()
            return
        }
        let block = currentBlockStyle
        if block.continuesOnReturn && isCaretInEmptyParagraph {
            setBlockStyle(.paragraph)
            return
        }
        let endedParagraphAttributes = typingAttributes
        super.insertText(text)

        if isCaretInEmptyParagraph {
            let next: BlockStyle = block.continuesOnReturn || block == .codeBlock ? block : .paragraph
            pendingBlockStyle = (selectedRange.location, next)
            typingAttributes = RichTextFormatter.setting(next, in: endedParagraphAttributes, defaultFont: defaultFont)
        }
        restoreTypingBlockStyle()
        setNeedsBlockDecorations()
        context?.refresh()
    }

    /// Marked text (e.g. Pinyin composition) is styled with the typing attributes too.
    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        restoreTypingBlockStyle()
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }

    /// Delete at the start of a list item, quote or code line removes the block style before joining paragraphs.
    override func deleteBackward() {
        guard markedTextRange == nil, selectedRange.length == 0 else {
            super.deleteBackward()
            return
        }
        restoreTypingBlockStyle()
        let block = currentBlockStyle
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        if block != .paragraph, !block.isHeading, selectedRange.location == paragraph.location {
            setBlockStyle(.paragraph)
            return
        }
        super.deleteBackward()
        restoreTypingBlockStyle()
    }

    /// Called whenever the selection moves, since UIKit has just recomputed the typing attributes.
    func selectionDidChange() {
        // A remembered style only applies to the empty paragraph it was chosen for.
        if let pending = pendingBlockStyle, selectedRange != NSRange(location: pending.location, length: 0) {
            pendingBlockStyle = nil
        }
        restoreTypingBlockStyle()
        setNeedsBlockDecorations()
        setNeedsCaretScroll()
    }

    /// The block style of the caret's paragraph, or the style it will get once typed into.
    ///
    /// Use this rather than `typingAttributes`: UIKit recomputes those at times of its own choosing
    /// and drops `.blockStyle` from them.
    var caretBlockStyle: BlockStyle {
        let location = selectedRange.location
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: NSRange(location: location, length: 0))
        if !isCaretInEmptyParagraph {
            return RichTextFormatter.blockStyle(of: textStorage, at: paragraph.location)
        }
        if let pending = pendingBlockStyle, pending.location == location {
            return pending.style
        }
        if paragraph.length > 0 {
            // An empty line that already has its newline character.
            return RichTextFormatter.blockStyle(of: textStorage, at: paragraph.location)
        }
        if location > 0 {
            // The empty trailing paragraph continues a list, quote or code block.
            let previous = RichTextFormatter.blockStyle(of: textStorage, at: location - 1)
            return previous.continuesOnReturn || previous == .codeBlock ? previous : .paragraph
        }
        return .paragraph
    }

    /// Puts the caret paragraph's block style back into the typing attributes.
    func restoreTypingBlockStyle() {
        guard selectedRange.length == 0 else {
            return
        }
        let block = caretBlockStyle
        if RichTextFormatter.blockStyle(in: typingAttributes) != block {
            typingAttributes[.blockStyle] = block == .paragraph ? nil : block.rawValue
        }
    }

    // MARK: Writing Direction

    /// Gives indented paragraphs an explicit writing direction that matches their text.
    ///
    /// TextKit indents a `.natural` paragraph by the system direction, not its text, so in a right-to-left
    /// locale an English list item would be indented on the wrong side, and vice versa. The direction is
    /// derived from content, so it's set without an undo action and recomputed as the text changes.
    func syncWritingDirections(in range: NSRange? = nil) {
        guard markedTextRange == nil, textStorage.length > 0 else {
            return
        }
        let searchRange = range.map { RichTextFormatter.paragraphRange(in: textStorage, for: $0) }
            ?? NSRange(location: 0, length: textStorage.length)
        let string = textStorage.string as NSString
        var changes: [(NSRange, NSParagraphStyle)] = []

        for paragraph in RichTextFormatter.paragraphRanges(in: textStorage, range: searchRange) where paragraph.length > 0 {
            let attributes = textStorage.attributes(at: paragraph.location, effectiveRange: nil)
            let block = RichTextFormatter.blockStyle(in: attributes)
            let style = attributes[.paragraphStyle] as? NSParagraphStyle ?? .default
            let wanted: NSWritingDirection = block.indent > 0
                ? RichTextFormatter.writingDirection(of: string.substring(with: paragraph)) ?? .natural
                : .natural
            if style.baseWritingDirection != wanted, let updated = style.mutableCopy() as? NSMutableParagraphStyle {
                updated.baseWritingDirection = wanted
                changes.append((paragraph, updated))
            }
        }
        guard !changes.isEmpty else {
            return
        }
        textStorage.beginEditing()
        for (paragraph, style) in changes {
            textStorage.addAttribute(.paragraphStyle, value: style, range: paragraph)
        }
        textStorage.endEditing()
        setNeedsBlockDecorations()
    }

    var isCaretInEmptyParagraph: Bool {
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        let content = (textStorage.string as NSString).substring(with: paragraph)
        return content.trimmingCharacters(in: .newlines).isEmpty
    }

    // MARK: Decorations

    /// Recomputes markers, bars and backgrounds from the current TextKit 2 layout.
    func updateBlockDecorations() {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager else {
            return
        }
        let documentStart = layoutManager.documentRange.location
        let contentWidth = bounds.width - textContainerInset.left - textContainerInset.right
        var decorations: [BlockDecorationView.Decoration] = []
        var previousBlock = BlockStyle.paragraph
        var ordinal = 0

        func append(_ block: BlockStyle, frame: CGRect, baseline: CGFloat, attributes: RichTextFormatter.Attributes) {
            let isRightToLeft = RichTextFormatter.isRightToLeft(attributes)
            ordinal = block == .numberedList ? (previousBlock == .numberedList ? ordinal + 1 : 1) : 0
            previousBlock = block

            let kind: BlockDecorationView.Decoration.Kind
            switch block {
            case .bulletList: kind = .bullet
            case .numberedList: kind = .number(ordinal)
            case .quote: kind = .quoteBar
            case .codeBlock: kind = .codeBackground
            default: return
            }
            var frame = frame
            // Consecutive code lines share one background, and consecutive quote paragraphs one bar.
            let isMergeable = kind == .codeBackground || kind == .quoteBar
            if isMergeable, let last = decorations.last, last.kind == kind, last.isRightToLeft == isRightToLeft,
               abs(last.frame.maxY - frame.minY) < 1 {
                frame = last.frame.union(frame)
                decorations.removeLast()
            }
            decorations.append(.init(
                kind: kind,
                frame: frame,
                baseline: baseline,
                indent: block.indent,
                isRightToLeft: isRightToLeft,
                font: RichTextFormatter.font(in: attributes, defaultFont: defaultFont),
                color: attributes[.foregroundColor] as? UIColor ?? defaultTextColor
            ))
        }

        layoutManager.enumerateTextLayoutFragments(from: documentStart, options: [.ensuresLayout]) { fragment in
            let offset = contentManager.offset(from: documentStart, to: fragment.rangeInElement.location)
            guard offset < textStorage.length else {
                return true
            }
            let attributes = textStorage.attributes(at: offset, effectiveRange: nil)
            let fragmentFrame = fragment.layoutFragmentFrame
            let frame = CGRect(
                x: textContainerInset.left,
                y: fragmentFrame.minY + textContainerInset.top,
                width: contentWidth,
                height: fragmentFrame.height
            )
            let firstLine = fragment.textLineFragments.first
            let baseline = frame.minY + (firstLine.map { $0.typographicBounds.minY + $0.glyphOrigin.y } ?? 0)
            append(RichTextFormatter.blockStyle(in: attributes), frame: frame, baseline: baseline, attributes: attributes)
            return true
        }

        // The empty paragraph after a trailing newline has no layout fragment; its style lives in the typing attributes.
        let isAtEmptyTrailingParagraph = selectedRange == NSRange(location: textStorage.length, length: 0)
            && (textStorage.length == 0 || textStorage.string.hasSuffix("\n"))
        if isAtEmptyTrailingParagraph {
            let caret = caretRect(for: endOfDocument)
            let font = RichTextFormatter.font(in: typingAttributes, defaultFont: defaultFont)
            let frame = CGRect(x: textContainerInset.left, y: caret.minY, width: contentWidth, height: caret.height)
            append(caretBlockStyle, frame: frame, baseline: caret.minY + font.ascender, attributes: typingAttributes)
        }

        decorationView.decorations = decorations
        // Decorations can land below the current bounds until SwiftUI grows the view. The view has no
        // backing store of its own, so covering the whole document costs nothing.
        let height = max(bounds.height, contentSize.height, decorations.map(\.frame.maxY).max() ?? 0)
        decorationView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        updateVisibleDecorationRect()
    }
}
