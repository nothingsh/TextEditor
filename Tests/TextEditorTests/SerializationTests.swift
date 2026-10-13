import XCTest
@testable import TextEditor

final class SerializationTests: XCTestCase {
    private let font = UIFont.preferredFont(forTextStyle: .body)

    private func blocks(_ text: NSAttributedString) -> [BlockStyle] {
        RichTextDocument.paragraphs(of: text, defaultFont: font, defaultTextColor: .label).map(\.block)
    }

    private func paragraphTexts(_ text: NSAttributedString) -> [String] {
        text.string.components(separatedBy: "\n")
    }

    private let sampleMarkdown = """
    # Title

    Some **bold**, *italic*, ~~gone~~, `code` and [a link](https://example.com).

    - one
    - two

    1. first
    2. second

    > quoted
    >
    > twice

    ```
    let a = 1
    let b = 2
    ```

    End.
    """

    // MARK: Markdown

    func testMarkdownImportMapsBlocks() {
        let text = RichTextSerializer.attributedString(markdown: sampleMarkdown)
        XCTAssertEqual(blocks(text), [
            .heading1, .paragraph, .bulletList, .bulletList, .numberedList, .numberedList,
            .quote, .quote, .codeBlock, .codeBlock, .paragraph,
        ])
        XCTAssertEqual(paragraphTexts(text)[8], "let a = 1")
    }

    func testMarkdownImportMapsInlineStyles() {
        let text = RichTextSerializer.attributedString(markdown: "Some **bold** and [link](https://example.com)")
        let string = text.string as NSString
        let boldFont = text.attribute(.font, at: string.range(of: "bold").location, effectiveRange: nil) as! UIFont
        XCTAssertTrue(boldFont.hasTrait(.traitBold))
        XCTAssertEqual(text.attribute(.link, at: string.range(of: "link").location, effectiveRange: nil) as? URL, URL(string: "https://example.com"))
    }

    func testMarkdownRoundTripIsStable() {
        let text = RichTextSerializer.attributedString(markdown: sampleMarkdown)
        let exported = RichTextSerializer.markdown(from: text)
        let reimported = RichTextSerializer.attributedString(markdown: exported)

        XCTAssertEqual(exported, RichTextSerializer.markdown(from: reimported))
        XCTAssertEqual(reimported.string, text.string)
        XCTAssertTrue(exported.contains("**bold**"))
        XCTAssertTrue(exported.contains("~~gone~~"))
        XCTAssertTrue(exported.contains("`code`"))
        XCTAssertTrue(exported.contains("[a link](https://example.com)"))
        XCTAssertTrue(exported.contains("2. second"))
        XCTAssertTrue(exported.contains("> quoted\n>\n> twice"))
    }

    func testMarkdownEscapesLiteralSyntax() {
        let text = NSAttributedString(string: "# not a heading *or* emphasis", attributes: [.font: font])
        let exported = RichTextSerializer.markdown(from: text)
        XCTAssertEqual(RichTextSerializer.attributedString(markdown: exported).string, text.string)
        XCTAssertEqual(blocks(RichTextSerializer.attributedString(markdown: exported)), [.paragraph])
    }

    func testMarkdownKeepsWhitespaceOutsideEmphasis() {
        let text = NSMutableAttributedString(string: "a bold b", attributes: [.font: font])
        text.addAttribute(.font, value: font.withTrait(.traitBold, enabled: true), range: NSRange(location: 1, length: 5))
        XCTAssertEqual(RichTextSerializer.markdown(from: text), "a **bold** b")
    }

    func testHeadingBoldIsNotRepeatedInMarkdown() {
        let text = RichTextSerializer.attributedString(markdown: "## Section")
        XCTAssertEqual(RichTextSerializer.markdown(from: text), "## Section")
    }

    // MARK: HTML

    func testHTMLExport() {
        let text = RichTextSerializer.attributedString(markdown: sampleMarkdown)
        let html = RichTextSerializer.html(from: text)
        XCTAssertTrue(html.hasPrefix("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<ul>\n<li>one</li>\n<li>two</li>\n</ul>"))
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<blockquote>\n<p>quoted</p>\n<p>twice</p>\n</blockquote>"))
        XCTAssertTrue(html.contains("<pre><code>let a = 1\nlet b = 2</code></pre>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">a link</a>"))
    }

    func testHTMLRoundTripKeepsUnderlineColorAndAlignment() {
        let html = #"<p style="text-align: center"><u>under</u> <span style="color: #DD4E48">red</span></p>"#
        let text = RichTextSerializer.attributedString(html: html)

        XCTAssertEqual(text.string, "under red")
        XCTAssertEqual(text.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(RichTextDocument.hexString(for: text.attribute(.foregroundColor, at: 6, effectiveRange: nil) as! UIColor), "#DD4E48")
        XCTAssertEqual((text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .center)
        XCTAssertEqual(RichTextSerializer.html(from: text), html)
    }

    func testHTMLImportIsForgiving() {
        let html = """
        <html><head><style>p { color: red }</style></head><body>
          <h4>Deep   heading</h4>
          <p>Line one<br>line two &amp; &lt;tags&gt; &#8212; &nbsp;done
          <ul><li><p>nested <b>bold</p></li><li>plain</ul>
          <pre><code>  keep
            spacing</code></pre>
          <unknown>still text</unknown>
        </body></html>
        """
        let text = RichTextSerializer.attributedString(html: html)
        XCTAssertEqual(blocks(text), [.heading3, .paragraph, .bulletList, .bulletList, .codeBlock, .codeBlock, .paragraph])
        let paragraphs = paragraphTexts(text)
        XCTAssertEqual(paragraphs[0], "Deep heading")
        XCTAssertEqual(paragraphs[1], "Line one\u{2028}line two & <tags> — \u{00A0}done")
        XCTAssertEqual(paragraphs[4], "  keep")
        XCTAssertEqual(paragraphs[6], "still text")
    }

    // MARK: Link Safety

    func testUnsafeLinkSchemesAreDroppedOnImportAndExport() {
        let fromHTML = RichTextSerializer.attributedString(html: #"<p><a href="javascript:alert(1)">click</a> <a href="https://ok.com">ok</a></p>"#)
        XCTAssertNil(fromHTML.attribute(.link, at: 0, effectiveRange: nil))
        XCTAssertNotNil(fromHTML.attribute(.link, at: 6, effectiveRange: nil))

        let fromMarkdown = RichTextSerializer.attributedString(markdown: "[click](javascript:alert(1))")
        XCTAssertNil(fromMarkdown.attribute(.link, at: 0, effectiveRange: nil))

        let crafted = NSAttributedString(string: "click", attributes: [.font: font, .link: URL(string: "javascript:alert(1)")!])
        XCTAssertFalse(RichTextSerializer.html(from: crafted).contains("javascript"))
        XCTAssertFalse(RichTextSerializer.markdown(from: crafted).contains("javascript"))
    }

    func testSafeAndRelativeLinksAreKept() {
        for link in ["https://a.com", "mailto:a@b.c", "tel:123", "/docs/page"] {
            XCTAssertTrue(RichTextDocument.isSafeLink(URL(string: link)!), link)
        }
        for link in ["javascript:alert(1)", "JavaScript:alert(1)", "data:text/html,x", "vbscript:x"] {
            XCTAssertFalse(RichTextDocument.isSafeLink(URL(string: link)!), link)
        }
    }

    // MARK: Images

    func testImagesRoundTripThroughDataURIs() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        }
        let text = NSMutableAttributedString(string: "pic ", attributes: [.font: font])
        text.append(NSAttributedString(attachment: NSTextAttachment(image: image)))

        for exported in [RichTextSerializer.markdown(from: text), RichTextSerializer.html(from: text)] {
            XCTAssertTrue(exported.contains("data:image/png;base64,"))
        }
        let fromMarkdown = RichTextSerializer.attributedString(markdown: RichTextSerializer.markdown(from: text))
        let fromHTML = RichTextSerializer.attributedString(html: RichTextSerializer.html(from: text))
        for imported in [fromMarkdown, fromHTML] {
            let attachment = imported.attribute(.attachment, at: imported.length - 1, effectiveRange: nil) as? NSTextAttachment
            XCTAssertNotNil(attachment?.image)
        }
    }

    // MARK: Archive

    func testArchiveIsLossless() throws {
        let text = NSMutableAttributedString(attributedString: RichTextSerializer.attributedString(markdown: sampleMarkdown))
        text.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 2))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2)).image { _ in }
        text.append(NSAttributedString(attachment: NSTextAttachment(image: image)))

        let restored = try RichTextSerializer.attributedString(archivedData: RichTextSerializer.archivedData(from: text))

        XCTAssertEqual(restored.string, text.string)
        XCTAssertEqual(blocks(restored), blocks(text))
        XCTAssertEqual(restored.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        let attachment = restored.attribute(.attachment, at: restored.length - 1, effectiveRange: nil) as? NSTextAttachment
        XCTAssertNotNil(attachment?.image)
    }

    func testCorruptArchiveThrows() {
        XCTAssertThrowsError(try RichTextSerializer.attributedString(archivedData: Data("nope".utf8)))
    }
}
