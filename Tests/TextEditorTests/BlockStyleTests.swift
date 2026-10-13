import XCTest
@testable import TextEditor

@MainActor
final class BlockStyleTests: XCTestCase {
    private var textView: RichTextView!
    private var context: RichTextContext!

    override func setUp() async throws {
        textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        context = RichTextContext()
        context.textView = textView
        textView.context = context
    }

    private func block(at location: Int) -> BlockStyle {
        RichTextFormatter.blockStyle(of: textView.textStorage, at: location)
    }

    private func font(at location: Int) -> UIFont {
        textView.textStorage.attribute(.font, at: location, effectiveRange: nil) as! UIFont
    }

    // MARK: Applying

    func testHeadingAppliesToWholeParagraphAndCanBeUndone() {
        textView.setContent(NSAttributedString(string: "Title\nBody"))
        textView.selectedRange = NSRange(location: 2, length: 0)

        context.setBlockStyle(.heading1)

        XCTAssertEqual(block(at: 0), .heading1)
        XCTAssertEqual(block(at: 4), .heading1)
        XCTAssertEqual(block(at: 6), .paragraph)
        XCTAssertTrue(font(at: 0).hasTrait(.traitBold))
        XCTAssertGreaterThan(font(at: 0).pointSize, textView.defaultFont.pointSize)
        XCTAssertEqual(context.blockStyle, .heading1)

        context.undo()
        XCTAssertEqual(block(at: 0), .paragraph)
        XCTAssertEqual(font(at: 0), textView.defaultFont)
    }

    func testLeavingHeadingRestoresBodyFontButKeepsItalic() {
        textView.setContent(NSAttributedString(string: "Title"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        context.toggle(.italic)
        context.setBlockStyle(.heading2)
        context.setBlockStyle(.paragraph)

        XCTAssertEqual(font(at: 0).pointSize, textView.defaultFont.pointSize)
        XCTAssertFalse(font(at: 0).hasTrait(.traitBold))
        XCTAssertTrue(font(at: 0).hasTrait(.traitItalic))
    }

    func testToggleListAcrossSelectionAndBack() {
        textView.setContent(NSAttributedString(string: "one\ntwo\nthree"))
        textView.selectedRange = NSRange(location: 1, length: 5)

        context.toggleBlockStyle(.bulletList)
        XCTAssertEqual([0, 4, 8].map(block(at:)), [.bulletList, .bulletList, .paragraph])
        let style = textView.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent, BlockStyle.bulletList.indent)

        context.toggleBlockStyle(.bulletList)
        XCTAssertEqual([0, 4, 8].map(block(at:)), [.paragraph, .paragraph, .paragraph])
    }

    func testBlockStyleOnEmptyDocumentGoesToTypingAttributes() {
        textView.setContent(NSAttributedString())
        context.setBlockStyle(.numberedList)

        XCTAssertEqual(RichTextFormatter.blockStyle(in: textView.typingAttributes), .numberedList)
        XCTAssertEqual(context.blockStyle, .numberedList)
        XCTAssertEqual(textView.decorationView.decorations.map(\.kind), [.number(1)])
    }

    // MARK: Return & Delete

    func testReturnContinuesListAndReturnOnEmptyItemEndsIt() {
        textView.setContent(NSAttributedString(string: "item"))
        textView.selectedRange = NSRange(location: 4, length: 0)
        context.setBlockStyle(.bulletList)

        textView.insertText("\n")
        XCTAssertEqual(RichTextFormatter.blockStyle(in: textView.typingAttributes), .bulletList)
        // UIKit strips custom typing attributes after each insertion; the next character must still be a list item.
        textView.insertText("z")
        XCTAssertEqual(block(at: 5), .bulletList)
        textView.insertText("\n")

        textView.insertText("\n")
        XCTAssertEqual(RichTextFormatter.blockStyle(in: textView.typingAttributes), .paragraph)
        XCTAssertEqual(textView.textStorage.string, "item\nz\n")
    }

    func testReturnAfterHeadingStartsBodyText() {
        textView.setContent(NSAttributedString(string: "Title"))
        textView.selectedRange = NSRange(location: 5, length: 0)
        context.setBlockStyle(.heading1)

        textView.insertText("\n")
        textView.insertText("b")

        XCTAssertEqual(block(at: 0), .heading1)
        XCTAssertEqual(block(at: 6), .paragraph)
        XCTAssertEqual(font(at: 6), textView.defaultFont)
    }

    func testDeleteAtStartOfListItemRemovesListFirst() {
        textView.setContent(NSAttributedString(string: "a\nb"))
        textView.selectedRange = NSRange(location: 2, length: 0)
        context.setBlockStyle(.bulletList)

        textView.deleteBackward()
        XCTAssertEqual(textView.textStorage.string, "a\nb")
        XCTAssertEqual(block(at: 2), .paragraph)

        textView.deleteBackward()
        XCTAssertEqual(textView.textStorage.string, "ab")
    }

    /// Enter, Delete twice, Enter: the new item's marker must show before anything is typed.
    func testMarkerSurvivesUIKitDroppingTypingAttributes() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "1. Typed item"))
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)

        textView.insertText("\n")
        textView.deleteBackward()
        textView.selectionDidChange()
        textView.deleteBackward()
        textView.selectionDidChange()
        XCTAssertNil(textView.pendingBlockStyle)

        textView.insertText("\n")
        // UIKit later recomputes typing attributes without our custom key, then relayout redraws.
        textView.typingAttributes[.blockStyle] = nil
        textView.updateBlockDecorations()

        XCTAssertEqual(textView.decorationView.decorations.map(\.kind), [.number(1), .number(2)])
        XCTAssertEqual(textView.formattingState.blockStyle, .numberedList)
    }

    // MARK: Decorations

    func testNumberingRestartsAfterInterruption() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "1. a\n2. b\n\nbreak\n\n1. c"))
        let numbers = textView.decorationView.decorations.compactMap { decoration -> Int? in
            if case .number(let ordinal) = decoration.kind { return ordinal }
            return nil
        }
        XCTAssertEqual(numbers, [1, 2, 1])
    }

    func testConsecutiveCodeLinesShareOneBackground() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "```\none\ntwo\n```"))
        XCTAssertEqual(textView.decorationView.decorations.map(\.kind), [.codeBackground])
    }

    // MARK: Links

    func testLinkSelectionThenEditWholeLinkFromCaret() {
        textView.setContent(NSAttributedString(string: "see docs here"))
        textView.selectedRange = NSRange(location: 4, length: 4)
        context.setLink(URL(string: "https://a.com"))
        XCTAssertEqual(textView.textStorage.attribute(.link, at: 4, effectiveRange: nil) as? URL, URL(string: "https://a.com"))

        textView.selectedRange = NSRange(location: 6, length: 0)
        XCTAssertEqual(context.link, URL(string: "https://a.com"))
        context.setLink(nil)
        XCTAssertNil(textView.textStorage.attribute(.link, at: 4, effectiveRange: nil))
        XCTAssertNil(textView.textStorage.attribute(.link, at: 7, effectiveRange: nil))
    }

    func testLinkWithCaretInsertsURLText() {
        textView.setContent(NSAttributedString(string: "go "))
        textView.selectedRange = NSRange(location: 3, length: 0)
        context.setLink(URL(string: "https://a.com"))

        XCTAssertEqual(textView.textStorage.string, "go https://a.com")
        XCTAssertNil(textView.typingAttributes[.link])
    }

    func testNormalizedURLAddsScheme() {
        XCTAssertEqual(RichTextView.normalizedURL(from: " example.com "), URL(string: "https://example.com"))
        XCTAssertEqual(RichTextView.normalizedURL(from: "mailto:a@b.c"), URL(string: "mailto:a@b.c"))
        XCTAssertNil(RichTextView.normalizedURL(from: "  "))
        XCTAssertNil(RichTextView.normalizedURL(from: "javascript:alert(1)"))
    }

    func testSetLinkRejectsUnsafeScheme() {
        textView.setContent(NSAttributedString(string: "click"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        context.setLink(URL(string: "javascript:alert(1)"))
        XCTAssertNil(textView.textStorage.attribute(.link, at: 0, effectiveRange: nil))
    }

    // MARK: Inline Code & Shortcuts

    func testInlineCodeToggle() {
        textView.setContent(NSAttributedString(string: "let x"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        context.toggle(.code)
        XCTAssertTrue(font(at: 0).hasTrait(.traitMonoSpace))
        context.toggle(.code)
        XCTAssertEqual(font(at: 0).familyName, textView.defaultFont.familyName)
    }

    func testStandardBoldfaceActionIsUndoable() {
        textView.setContent(NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        textView.toggleBoldface(nil)
        XCTAssertTrue(font(at: 0).hasTrait(.traitBold))
        context.undo()
        XCTAssertFalse(font(at: 0).hasTrait(.traitBold))
    }
}
