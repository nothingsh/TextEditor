//
//  RichTextView+Blocks.swift
//
//

import UIKit

extension RichTextView {
    // MARK: Block Commands

    /// Applies `block` to every paragraph the selection touches. List items that stay list items keep their level.
    func setBlockStyle(_ block: BlockStyle) {
        updateParagraphFormats(actionName: "Paragraph Style") { $0.with(block) }
    }

    /// Turns `block` on, or back into plain paragraphs when the whole selection already has it.
    func toggleBlockStyle(_ block: BlockStyle) {
        setBlockStyle(currentBlockStyle == block ? .paragraph : block)
    }

    var currentBlockStyle: BlockStyle {
        formattingState.blockStyle
    }

    /// Nests every list item the selection touches one level deeper, up to `BlockStyle.maxListLevel`.
    func indentListItems() {
        updateParagraphFormats(actionName: "Indent") { format in
            ParagraphFormat(block: format.block, level: format.level + 1, isChecked: format.isChecked)
        }
    }

    /// Moves every list item the selection touches one level out.
    func outdentListItems() {
        updateParagraphFormats(actionName: "Outdent") { format in
            ParagraphFormat(block: format.block, level: format.level - 1, isChecked: format.isChecked)
        }
    }

    /// Ticks every checklist item the selection touches, or unticks them all when they're all ticked.
    func toggleChecklistItems() {
        let formats = selectedParagraphFormats.filter { $0.block == .checklist }
        let check = !formats.isEmpty && !formats.allSatisfy(\.isChecked)
        updateParagraphFormats(actionName: check ? "Check" : "Uncheck") { format in
            ParagraphFormat(block: format.block, level: format.level, isChecked: check)
        }
    }

    /// Ticks or unticks the checklist item at `location`, wherever the selection is.
    func toggleChecklistItem(at location: Int) {
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: NSRange(location: location, length: 0))
        let format = RichTextFormatter.paragraphFormat(of: textStorage, at: paragraph.location)
        guard format.block == .checklist, paragraph.length > 0 else {
            return
        }
        let toggled = ParagraphFormat(block: .checklist, level: format.level, isChecked: !format.isChecked)
        editAttributes(in: paragraph, actionName: toggled.isChecked ? "Check" : "Uncheck") { text, range in
            RichTextFormatter.transformAttributes(in: text, range: range) { attributes in
                RichTextFormatter.setting(toggled, in: attributes, defaultFont: defaultFont)
            }
        }
    }

    /// The formats of the paragraphs the selection touches, including an empty one only described by the typing attributes.
    var selectedParagraphFormats: [ParagraphFormat] {
        if selectedRange.length == 0 {
            return [caretParagraphFormat]
        }
        let range = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        return RichTextFormatter.paragraphRanges(in: textStorage, range: range).map {
            RichTextFormatter.paragraphFormat(of: textStorage, at: $0.location)
        }
    }

    /// Rewrites the format of each paragraph the selection touches, from its own current format,
    /// and of the text typed next.
    private func updateParagraphFormats(actionName: String, _ transform: (ParagraphFormat) -> ParagraphFormat) {
        restoreTypingBlockStyle()
        let typingFormat = transform(selectedRange.length == 0 ? caretParagraphFormat : RichTextFormatter.paragraphFormat(in: typingAttributes))
        typingAttributes = RichTextFormatter.setting(typingFormat, in: typingAttributes, defaultFont: defaultFont)
        if selectedRange.length == 0 && isCaretInEmptyParagraph {
            pendingParagraphFormat = (selectedRange.location, typingFormat)
        }
        let range = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        guard range.length > 0 else {
            // An empty trailing paragraph only exists in the typing attributes.
            setNeedsBlockDecorations()
            context?.refresh()
            return
        }
        editAttributes(in: range, actionName: actionName) { text, range in
            for paragraph in RichTextFormatter.paragraphRanges(in: text, range: range) where paragraph.length > 0 {
                let format = transform(RichTextFormatter.paragraphFormat(of: text, at: paragraph.location))
                RichTextFormatter.transformAttributes(in: text, range: paragraph) { attributes in
                    RichTextFormatter.setting(format, in: attributes, defaultFont: defaultFont)
                }
            }
        }
    }

    // MARK: Typing

    /// Return on an empty list item or quote ends the list instead of adding another empty item,
    /// or moves a nested item out a level, and a new paragraph after a heading starts as body text.
    /// Tab in a list item nests it.
    override func insertText(_ text: String) {
        restoreTypingBlockStyle()
        if applyMarkdownShortcut(typing: text) {
            return
        }
        if text == "\t", markedTextRange == nil, currentBlockStyle.isList {
            indentListItems()
            return
        }
        guard text == "\n", markedTextRange == nil, selectedRange.length == 0 else {
            super.insertText(text)
            restoreTypingBlockStyle()
            return
        }
        let format = caretParagraphFormat
        if format.block.continuesOnReturn && isCaretInEmptyParagraph {
            format.level > 0 ? outdentListItems() : setBlockStyle(.paragraph)
            return
        }
        let endedParagraphAttributes = typingAttributes
        super.insertText(text)

        if isCaretInEmptyParagraph {
            let next = format.block.continuesOnReturn || format.block == .codeBlock
                ? ParagraphFormat(block: format.block, level: format.level)
                : .paragraph
            pendingParagraphFormat = (selectedRange.location, next)
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
    /// A nested list item moves out a level first.
    override func deleteBackward() {
        guard markedTextRange == nil, selectedRange.length == 0 else {
            super.deleteBackward()
            return
        }
        restoreTypingBlockStyle()
        let format = caretParagraphFormat
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        if format.block != .paragraph, !format.block.isHeading, selectedRange.location == paragraph.location {
            format.level > 0 ? outdentListItems() : setBlockStyle(.paragraph)
            return
        }
        super.deleteBackward()
        restoreTypingBlockStyle()
    }

    /// Called whenever the selection moves, since UIKit has just recomputed the typing attributes.
    func selectionDidChange() {
        // A remembered format only applies to the empty paragraph it was chosen for.
        if let pending = pendingParagraphFormat, selectedRange != NSRange(location: pending.location, length: 0) {
            pendingParagraphFormat = nil
        }
        restoreTypingBlockStyle()
        setNeedsBlockDecorations()
        setNeedsCaretScroll()
    }

    /// The block style of the caret's paragraph, or the style it will get once typed into.
    var caretBlockStyle: BlockStyle {
        caretParagraphFormat.block
    }

    /// The format of the caret's paragraph, or the format it will get once typed into.
    ///
    /// Use this rather than `typingAttributes`: UIKit recomputes those at times of its own choosing
    /// and drops the editor's custom attributes from them.
    var caretParagraphFormat: ParagraphFormat {
        let location = selectedRange.location
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: NSRange(location: location, length: 0))
        if !isCaretInEmptyParagraph {
            return RichTextFormatter.paragraphFormat(of: textStorage, at: paragraph.location)
        }
        if let pending = pendingParagraphFormat, pending.location == location {
            return pending.format
        }
        if paragraph.length > 0 {
            // An empty line that already has its newline character.
            return RichTextFormatter.paragraphFormat(of: textStorage, at: paragraph.location)
        }
        if location > 0 {
            // The empty trailing paragraph continues a list, quote or code block, unticked.
            let previous = RichTextFormatter.paragraphFormat(of: textStorage, at: location - 1)
            let continues = previous.block.continuesOnReturn || previous.block == .codeBlock
            return continues ? ParagraphFormat(block: previous.block, level: previous.level) : .paragraph
        }
        return .paragraph
    }

    /// Puts the caret paragraph's format back into the typing attributes.
    func restoreTypingBlockStyle() {
        guard selectedRange.length == 0 else {
            return
        }
        let format = caretParagraphFormat
        if RichTextFormatter.paragraphFormat(in: typingAttributes) != format {
            typingAttributes[.blockStyle] = format.block == .paragraph ? nil : format.block.rawValue
            typingAttributes[.listLevel] = format.level > 0 ? format.level : nil
            typingAttributes[.checklistChecked] = format.isChecked ? true : nil
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
            let format = RichTextFormatter.paragraphFormat(in: attributes)
            let style = attributes[.paragraphStyle] as? NSParagraphStyle ?? .default
            let wanted: NSWritingDirection = format.indent > 0
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
    ///
    /// A growing editor shows all of its text, so it's all laid out anyway. A scrolling one only lays out
    /// what's near the screen, so decorations are computed for a screen above and below the visible region,
    /// and again once scrolling leaves it.
    func updateBlockDecorations() {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager else {
            return
        }
        let documentStart = layoutManager.documentRange.location
        let contentWidth = bounds.width - textContainerInset.left - textContainerInset.right
        var decorations: [BlockDecorationView.Decoration] = []
        var numbering = ListNumbering()

        var start = documentStart
        var regionStart: CGFloat = 0
        let regionEnd = scrollsContent ? bounds.maxY + bounds.height : .greatestFiniteMagnitude
        var reachedRegionEnd = false
        if scrollsContent {
            let top = CGPoint(x: 0, y: max(0, bounds.minY - bounds.height - textContainerInset.top))
            let fragment = layoutManager.textLayoutFragment(for: top)
            if let location = fragment?.rangeInElement.location ?? layoutManager.textViewportLayoutController.viewportRange?.location {
                start = location
                let offset = contentManager.offset(from: documentStart, to: location)
                numbering = numberingOfListItems(before: offset)
                regionStart = offset == 0 ? 0 : (fragment?.layoutFragmentFrame.minY ?? bounds.minY) + textContainerInset.top
            }
        }

        func append(_ format: ParagraphFormat, at location: Int, frame: CGRect, baseline: CGFloat, attributes: RichTextFormatter.Attributes) {
            let isRightToLeft = RichTextFormatter.isRightToLeft(attributes)
            let ordinal = numbering.next(format)

            let kind: BlockDecorationView.Decoration.Kind
            switch format.block {
            case .bulletList: kind = .bullet(level: format.level)
            case .numberedList: kind = .number(ordinal)
            case .checklist: kind = .checkbox(isChecked: format.isChecked)
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
                paragraphLocation: location,
                frame: frame,
                baseline: baseline,
                indent: format.indent,
                isRightToLeft: isRightToLeft,
                font: RichTextFormatter.font(in: attributes, defaultFont: defaultFont),
                color: attributes[.foregroundColor] as? UIColor ?? defaultTextColor
            ))
        }

        layoutManager.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let offset = contentManager.offset(from: documentStart, to: fragment.rangeInElement.location)
            guard offset < textStorage.length else {
                return true
            }
            let fragmentFrame = fragment.layoutFragmentFrame
            if fragmentFrame.minY + textContainerInset.top > regionEnd {
                reachedRegionEnd = true
                return false
            }
            let attributes = textStorage.attributes(at: offset, effectiveRange: nil)
            let frame = CGRect(
                x: textContainerInset.left,
                y: fragmentFrame.minY + textContainerInset.top,
                width: contentWidth,
                height: fragmentFrame.height
            )
            let firstLine = fragment.textLineFragments.first
            let baseline = frame.minY + (firstLine.map { $0.typographicBounds.minY + $0.glyphOrigin.y } ?? 0)
            append(RichTextFormatter.paragraphFormat(in: attributes), at: offset, frame: frame, baseline: baseline, attributes: attributes)
            return true
        }

        // The empty paragraph after a trailing newline has no layout fragment; its style lives in the typing attributes.
        let isAtEmptyTrailingParagraph = selectedRange == NSRange(location: textStorage.length, length: 0)
            && (textStorage.length == 0 || textStorage.string.hasSuffix("\n"))
        if isAtEmptyTrailingParagraph && !reachedRegionEnd {
            let caret = caretRect(for: endOfDocument)
            let font = RichTextFormatter.font(in: typingAttributes, defaultFont: defaultFont)
            let frame = CGRect(x: textContainerInset.left, y: caret.minY, width: contentWidth, height: caret.height)
            append(caretParagraphFormat, at: textStorage.length, frame: frame, baseline: caret.minY + font.ascender, attributes: typingAttributes)
        }

        decorationView.decorations = decorations
        decoratedRegion = scrollsContent ? regionStart...(reachedRegionEnd ? regionEnd : .greatestFiniteMagnitude) : nil
        // Decorations can land below the current bounds until SwiftUI grows the view. The view has no
        // backing store of its own, so covering the whole document costs nothing.
        let height = max(bounds.height, contentSize.height, decorations.map(\.frame.maxY).max() ?? 0)
        decorationView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        updateVisibleDecorationRect()
    }

    /// Numbering as it stands just before the paragraph at `location`, counting back to the start of its list.
    private func numberingOfListItems(before location: Int) -> ListNumbering {
        let string = textStorage.string as NSString
        var starts: [Int] = []
        var cursor = location
        while cursor > 0 {
            let previous = string.paragraphRange(for: NSRange(location: cursor - 1, length: 0))
            guard RichTextFormatter.blockStyle(of: textStorage, at: previous.location).isList else {
                break
            }
            starts.append(previous.location)
            cursor = previous.location
        }
        var numbering = ListNumbering()
        for start in starts.reversed() {
            _ = numbering.next(RichTextFormatter.paragraphFormat(of: textStorage, at: start))
        }
        return numbering
    }
}
