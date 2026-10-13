import XCTest
@testable import TextEditor

@MainActor
final class MarkdownShortcutTests: XCTestCase {
    private var textView: RichTextView!

    override func setUp() async throws {
        textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        textView.setContent(NSAttributedString())
    }

    /// One key per run loop turn, like a real keyboard, so each keystroke is its own undo group.
    private func type(_ text: String) {
        for character in text {
            textView.insertText(String(character))
            RunLoop.current.run(until: Date())
        }
    }

    private var string: String {
        textView.textStorage.string
    }

    private func block(at location: Int = 0) -> BlockStyle {
        RichTextFormatter.blockStyle(of: textView.textStorage, at: location)
    }

    private func isStyle(_ style: TextStyle, at range: NSRange) -> Bool {
        RichTextFormatter.isStyle(style, activeIn: textView.textStorage, range: range, defaultFont: textView.defaultFont)
    }

    // MARK: Blocks

    func testBlockPrefixesBecomeBlockStyles() {
        let cases: [(String, BlockStyle)] = [
            ("# ", .heading1), ("## ", .heading2), ("### ", .heading3),
            ("- ", .bulletList), ("* ", .bulletList), ("12. ", .numberedList),
            ("> ", .quote), ("``` ", .codeBlock),
        ]
        for (prefix, expected) in cases {
            setUp()
            textView.setContent(NSAttributedString())
            type(prefix + "x")
            XCTAssertEqual(string, "x", prefix)
            XCTAssertEqual(block(), expected, prefix)
        }
    }

    func testBlockShortcutAppliesToExistingParagraphText() {
        textView.setContent(NSAttributedString(string: "Title"))
        textView.selectedRange = NSRange(location: 0, length: 0)
        type("# ")
        XCTAssertEqual(string, "Title")
        XCTAssertEqual(block(), .heading1)
    }

    func testBlockShortcutOnlyAtParagraphStartAndInPlainParagraphs() {
        type("a - b")
        XCTAssertEqual(string, "a - b")
        XCTAssertEqual(block(), .paragraph)

        textView.setContent(NSAttributedString())
        type("- item")
        textView.insertText("\n")
        type("- ")
        XCTAssertEqual(string, "item\n- ", "a list item doesn't nest another list")
    }

    func testUndoBringsBackTypedMarkdown() {
        type("# ")
        XCTAssertEqual(string, "")
        XCTAssertEqual(textView.caretBlockStyle, .heading1)
        textView.undoManager?.undo()
        XCTAssertEqual(string, "# ")
        XCTAssertEqual(RichTextFormatter.blockStyle(in: textView.typingAttributes), .paragraph)
    }

    // MARK: Inline

    func testInlineMarkersBecomeStyles() {
        let cases: [(String, TextStyle)] = [
            ("**bold**", .bold), ("__bold__", .bold), ("*it*", .italic), ("_it_", .italic),
            ("~~gone~~", .strikethrough), ("`code`", .code),
        ]
        for (typed, style) in cases {
            textView.setContent(NSAttributedString())
            type("a " + typed)
            let word = typed.trimmingCharacters(in: CharacterSet(charactersIn: "*_~`"))
            XCTAssertEqual(string, "a " + word, typed)
            XCTAssertTrue(isStyle(style, at: NSRange(location: 2, length: (word as NSString).length)), typed)
            XCTAssertFalse(isStyle(style, at: NSRange(location: 0, length: 1)), typed)
        }
    }

    func testTypingAfterInlineShortcutIsPlain() {
        type("**bold** next")
        XCTAssertEqual(string, "bold next")
        XCTAssertFalse(isStyle(.bold, at: NSRange(location: 5, length: 4)))
    }

    func testInlineShortcutUndoRestoresMarkers() {
        type("*it*")
        textView.undoManager?.undo()
        XCTAssertEqual(string, "*it*")
        XCTAssertFalse(isStyle(.italic, at: NSRange(location: 0, length: 4)))
    }

    func testNoFalsePositives() {
        type("snake_case_name 2 * 3 * 4 a ** b **")
        XCTAssertEqual(string, "snake_case_name 2 * 3 * 4 a ** b **")
    }

    func testNoShortcutsInsideCodeBlocks() {
        type("``` ")
        type("**not bold**")
        XCTAssertEqual(string, "**not bold**")
    }

    func testShortcutsCanBeDisabled() {
        textView.isMarkdownShortcutsEnabled = false
        type("# **x**")
        XCTAssertEqual(string, "# **x**")
        XCTAssertEqual(block(), .paragraph)
    }
}
