//
//  RichTextSerializer.swift
//
//

import UIKit
import UniformTypeIdentifiers

/// Converts editor content to and from Markdown, HTML and a lossless archive.
///
/// | Format   | Keeps                                                              | Drops                              |
/// |----------|--------------------------------------------------------------------|------------------------------------|
/// | Archive  | everything                                                         | nothing                            |
/// | HTML     | blocks, inline styles, links, colors, alignment, images            | font sizes                         |
/// | Markdown | blocks, bold, italic, strikethrough, code, links, images           | underline, colors, sizes, alignment |
///
/// Images are embedded as base64 `data:` URIs in HTML and Markdown.
public enum RichTextSerializer {
    // MARK: Markdown

    public static func markdown(from text: NSAttributedString, defaultFont: UIFont = .preferredFont(forTextStyle: .body)) -> String {
        MarkdownWriter.markdown(from: RichTextDocument.paragraphs(of: text, defaultFont: defaultFont, defaultTextColor: .label))
    }

    public static func attributedString(
        markdown: String,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label
    ) -> NSAttributedString {
        RichTextDocument.build(MarkdownReader.paragraphs(from: markdown), defaultFont: defaultFont, defaultTextColor: textColor)
    }

    // MARK: HTML

    /// An HTML fragment, without `<html>` or `<body>`, ready to embed in a page.
    public static func html(from text: NSAttributedString, defaultFont: UIFont = .preferredFont(forTextStyle: .body)) -> String {
        HTMLWriter.html(from: RichTextDocument.paragraphs(of: text, defaultFont: defaultFont, defaultTextColor: .label))
    }

    public static func attributedString(
        html: String,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label
    ) -> NSAttributedString {
        RichTextDocument.build(HTMLReader.paragraphs(from: html), defaultFont: defaultFont, defaultTextColor: textColor)
    }

    // MARK: Archive

    /// A lossless keyed archive, the format to use for saving drafts.
    ///
    /// Images are stored as their encoded bytes. Images inserted in the editor were encoded once on insertion,
    /// so saving doesn't re-encode them.
    public static func archivedData(from text: NSAttributedString) throws -> Data {
        let archivable = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: archivable.length)
        // Archive only the bytes: image-backed attachments would otherwise lose their image.
        archivable.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, let payload = ImageAttachments.payload(of: attachment) else {
                return
            }
            archivable.addAttribute(.attachment, value: NSTextAttachment(data: payload.data, ofType: payload.type.identifier), range: range)
        }
        return try NSKeyedArchiver.archivedData(withRootObject: archivable, requiringSecureCoding: true)
    }

    public static func attributedString(archivedData data: Data) throws -> NSAttributedString {
        let allowedClasses: [AnyClass] = [
            NSAttributedString.self, NSMutableAttributedString.self, NSString.self, NSNumber.self, NSData.self,
            NSURL.self, NSDictionary.self, NSArray.self, UIFont.self, UIColor.self,
            NSParagraphStyle.self, NSMutableParagraphStyle.self, NSTextTab.self, NSTextAttachment.self,
        ]
        guard let text = try NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) as? NSAttributedString else {
            throw CocoaError(.coderReadCorrupt)
        }
        let restored = NSMutableAttributedString(attributedString: text)
        restored.enumerateAttribute(.attachment, in: NSRange(location: 0, length: restored.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, attachment.image == nil,
                  let payload = ImageAttachments.payload(of: attachment),
                  let displayable = ImageAttachments.attachment(for: payload) else {
                return
            }
            restored.addAttribute(.attachment, value: displayable, range: range)
        }
        return restored
    }
}
