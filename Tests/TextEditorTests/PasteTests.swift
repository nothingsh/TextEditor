import UniformTypeIdentifiers
import XCTest
@testable import TextEditor

@MainActor
final class PasteTests: XCTestCase {
    private let font = UIFont.preferredFont(forTextStyle: .body)
    private var textView: RichTextView!

    override func setUp() async throws {
        textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
    }

    private func html(_ source: String) -> NSAttributedString {
        RichTextSerializer.attributedString(html: source, defaultFont: font)
    }

    private func blocks(_ text: NSAttributedString) -> [BlockStyle] {
        RichTextFormatter.paragraphRanges(in: text, range: NSRange(location: 0, length: text.length))
            .map { RichTextFormatter.blockStyle(of: text, at: $0.location) }
    }

    private func isBold(_ text: NSAttributedString, _ substring: String) -> Bool {
        let range = (text.string as NSString).range(of: substring)
        return RichTextFormatter.isStyle(.bold, activeIn: text, range: range, defaultFont: font)
    }

    // MARK: HTML Inline CSS

    func testCSSFontWeightAndStyleBecomeInlineStyles() {
        let text = html(#"<p><span style="font-weight: 700">bold</span> <span style="font-style:italic">it</span> <span style="text-decoration: underline line-through">both</span></p>"#)
        XCTAssertTrue(isBold(text, "bold"))
        let state = RichTextFormatter.isStyle(.italic, activeIn: text, range: (text.string as NSString).range(of: "it"), defaultFont: font)
        XCTAssertTrue(state)
        let both = (text.string as NSString).range(of: "both")
        XCTAssertTrue(RichTextFormatter.isStyle(.underline, activeIn: text, range: both, defaultFont: font))
        XCTAssertTrue(RichTextFormatter.isStyle(.strikethrough, activeIn: text, range: both, defaultFont: font))
    }

    func testGoogleDocsNormalWeightWrapperIsNotBold() {
        let text = html(#"<b style="font-weight:normal;" id="docs-internal-guid-1"><p><span>plain</span></p></b>"#)
        XCTAssertEqual(text.string, "plain")
        XCTAssertFalse(isBold(text, "plain"))
    }

    // MARK: Foreign Rich Text

    func testForeignTextIsNormalized() {
        let foreign = NSMutableAttributedString()
        let body = UIFont(name: "Georgia", size: 12)!
        foreign.append(NSAttributedString(string: "Title\n", attributes: [.font: UIFont.boldSystemFont(ofSize: 20)]))
        let list = NSMutableParagraphStyle()
        list.textLists = [NSTextList(markerFormat: .disc, options: 0)]
        foreign.append(NSAttributedString(string: "\t•\tItem\n", attributes: [.font: body, .paragraphStyle: list]))
        foreign.append(NSAttributedString(string: "black ", attributes: [.font: body, .foregroundColor: UIColor.black]))
        foreign.append(NSAttributedString(string: "red\n", attributes: [.font: body, .foregroundColor: UIColor.red]))
        foreign.append(NSAttributedString(string: "let x = 1", attributes: [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)]))

        let text = PastedText.normalized(foreign: foreign, defaultFont: font, textColor: .label)

        XCTAssertEqual(text.string, "Title\nItem\nblack red\nlet x = 1")
        XCTAssertEqual(blocks(text), [.heading1, .bulletList, .paragraph, .codeBlock])
        let black = (text.string as NSString).range(of: "black")
        let red = (text.string as NSString).range(of: "red")
        XCTAssertEqual(text.attribute(.foregroundColor, at: black.location, effectiveRange: nil) as? UIColor, .label)
        XCTAssertEqual(text.attribute(.foregroundColor, at: red.location, effectiveRange: nil) as? UIColor, .red)
        // Foreign fonts are replaced by the editor's.
        XCTAssertEqual((text.attribute(.font, at: black.location, effectiveRange: nil) as? UIFont)?.familyName, font.familyName)
    }

    func testForeignTrailingNewlineIsKept() {
        let foreign = NSAttributedString(string: "line\n", attributes: [.font: font])
        XCTAssertEqual(PastedText.normalized(foreign: foreign, defaultFont: font, textColor: .label).string, "line\n")
    }

    // MARK: Pasteboard

    func testPasteboardRoundTripsEditorContent() throws {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        let source = RichTextSerializer.attributedString(markdown: "- **one**\n- two", defaultFont: font)

        PastedText.addRepresentations(of: source, to: pasteboard)

        let text = try XCTUnwrap(PastedText.text(from: pasteboard, defaultFont: font, textColor: .label))
        XCTAssertEqual(text.string, "one\ntwo")
        XCTAssertEqual(blocks(text), [.bulletList, .bulletList])
        XCTAssertTrue(isBold(text, "one"))
        XCTAssertNotNil(pasteboard.value(forPasteboardType: UTType.html.identifier))
    }

    func testPlainTextPasteboardIsLeftToUIKit() {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        pasteboard.string = "plain"
        XCTAssertNil(PastedText.text(from: pasteboard, defaultFont: font, textColor: .label))
    }

    // MARK: Joining Paragraphs

    func testSingleParagraphTakesDestinationStyle() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- ab", defaultFont: font))
        textView.selectedRange = NSRange(location: 1, length: 0)

        textView.paste(html("<h1>XY</h1>"))

        XCTAssertEqual(textView.textStorage.string, "aXYb")
        XCTAssertEqual(blocks(textView.textStorage), [.bulletList])
        XCTAssertEqual(textView.selectedRange, NSRange(location: 3, length: 0))
    }

    func testMultipleParagraphsJoinTheirNeighbours() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- ab", defaultFont: font))
        textView.selectedRange = NSRange(location: 1, length: 0)

        textView.paste(html("<p>one</p><h2>two</h2>"))

        XCTAssertEqual(textView.textStorage.string, "aone\ntwob")
        // The first pasted paragraph joins the list item; the rest of the item joins the heading.
        XCTAssertEqual(blocks(textView.textStorage), [.bulletList, .heading2])
        XCTAssertEqual(textView.selectedRange, NSRange(location: 8, length: 0))
    }

    func testParagraphsPastedAtLineStartKeepTheirStyles() {
        textView.setContent(NSAttributedString(string: "end"))
        textView.selectedRange = NSRange(location: 0, length: 0)

        textView.paste(PastedText.normalized(foreign: NSAttributedString(string: "a\nb\n", attributes: [.font: font]), defaultFont: font, textColor: .label))
        XCTAssertEqual(textView.textStorage.string, "a\nb\nend")

        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.paste(html("<ul><li>x</li><li>y</li></ul>"))
        XCTAssertEqual(textView.textStorage.string, "x\nya\nb\nend")
        XCTAssertEqual(blocks(textView.textStorage), [.bulletList, .bulletList, .paragraph, .paragraph])
    }

    func testPasteIsOneUndoStep() {
        textView.setContent(NSAttributedString(string: "ab"))
        textView.selectedRange = NSRange(location: 1, length: 0)

        textView.paste(html("<p>one</p><p>two</p>"))
        XCTAssertEqual(textView.textStorage.string, "aone\ntwob")

        textView.editorUndoManager?.undo()
        XCTAssertEqual(textView.textStorage.string, "ab")
    }
}
