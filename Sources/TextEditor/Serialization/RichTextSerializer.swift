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
/// Images are embedded as base64 `data:` URIs in HTML and Markdown. On import, only `data:` URI images
/// are loaded; remote images are never fetched, so Markdown keeps them as a link and HTML drops them.
///
/// The `defaultFont` and `textColor` parameters describe the editor's body text. On export they tell
/// which runs are styled and which are plain; on import they're the font and color given to plain text.
/// The editor uses the body text style and `.label`, the defaults here.
public enum RichTextSerializer {
    // MARK: Markdown

    /// CommonMark with GitHub-style strikethrough.
    ///
    /// - Parameters:
    ///   - text: The document to write.
    ///   - defaultFont: The body font, so headings and inline styles are told apart from body text.
    public static func markdown(from text: NSAttributedString, defaultFont: UIFont = .preferredFont(forTextStyle: .body)) -> String {
        MarkdownWriter.markdown(from: RichTextDocument.paragraphs(of: text, defaultFont: defaultFont, defaultTextColor: .label))
    }

    /// Reads CommonMark, including GitHub-style strikethrough.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source.
    ///   - defaultFont: The body font; headings and code are derived from it.
    ///   - textColor: The color of text without an explicit color.
    public static func attributedString(
        markdown: String,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label
    ) -> NSAttributedString {
        RichTextDocument.build(MarkdownReader.paragraphs(from: markdown), defaultFont: defaultFont, defaultTextColor: textColor)
    }

    // MARK: HTML

    /// An HTML fragment, without `<html>` or `<body>`, ready to embed in a page.
    ///
    /// - Parameters:
    ///   - text: The document to write.
    ///   - defaultFont: The body font, so headings and inline styles are told apart from body text.
    ///   - textColor: The body text color. Text in this color gets no `color` style, so the page's own color applies.
    public static func html(
        from text: NSAttributedString,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label
    ) -> String {
        HTMLWriter.html(from: RichTextDocument.paragraphs(of: text, defaultFont: defaultFont, defaultTextColor: textColor))
    }

    /// Reads everyday HTML. Unclosed tags, unknown tags and entities are fine, and `<script>`, `<style>`
    /// and `<head>` contents are dropped. Links with unsafe schemes such as `javascript:` are removed.
    ///
    /// - Parameters:
    ///   - html: An HTML document or fragment.
    ///   - defaultFont: The body font; headings and code are derived from it.
    ///   - textColor: The color of text without an explicit color.
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

    /// Restores a document saved with ``archivedData(from:)``.
    ///
    /// - Throws: An error if `data` isn't an archived attributed string, or holds classes other than
    ///   the text, font, color, paragraph style, link and attachment types the editor writes.
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
