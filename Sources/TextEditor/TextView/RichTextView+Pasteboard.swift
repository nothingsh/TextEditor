//
//  RichTextView+Pasteboard.swift
//
//

import UIKit

extension RichTextView {
    // MARK: Copy and Paste

    /// Adds the editor's own representations, so pasting back into an editor is lossless.
    override func copy(_ sender: Any?) {
        let copied = textStorage.attributedSubstring(from: selectedRange)
        super.copy(sender)
        PastedText.addRepresentations(of: copied, to: .general)
    }

    override func cut(_ sender: Any?) {
        let copied = textStorage.attributedSubstring(from: selectedRange)
        super.cut(sender)
        PastedText.addRepresentations(of: copied, to: .general)
    }

    /// Rich text is rebuilt in the editor's vocabulary before it's inserted; plain text and lone images
    /// keep UIKit's behavior of taking the typing attributes, apart from images being stored like inserted ones.
    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        if let text = PastedText.text(from: pasteboard, defaultFont: defaultFont, textColor: defaultTextColor) {
            paste(text)
        } else if !pasteboard.hasStrings, let image = pasteboard.image {
            insertImage(image)
        } else {
            super.paste(sender)
        }
    }

    /// Replaces the selection with `pasted`, which is already in the editor's vocabulary, as one undoable step.
    func paste(_ pasted: NSAttributedString) {
        guard pasted.length > 0 else {
            return
        }
        restoreTypingBlockStyle()
        let edit = PastedText.edit(
            pasting: pasted,
            into: textStorage,
            selection: selectedRange,
            destination: destinationParagraphAttributes,
            defaultFont: defaultFont
        )
        replaceCharacters(in: edit.range, with: edit.replacement, selecting: edit.selection, actionName: "Paste")
        fitAttachmentsToWidth()
        setNeedsCaretScroll()
    }

    /// The paragraph a paste lands in. An empty paragraph's style may only exist in the typing attributes.
    private var destinationParagraphAttributes: RichTextFormatter.Attributes {
        let paragraph = RichTextFormatter.paragraphRange(in: textStorage, for: NSRange(location: selectedRange.location, length: 0))
        if paragraph.length == 0 || (selectedRange.length == 0 && isCaretInEmptyParagraph) {
            return RichTextFormatter.setting(caretBlockStyle, in: typingAttributes, defaultFont: defaultFont)
        }
        return textStorage.attributes(at: paragraph.location, effectiveRange: nil)
    }
}
