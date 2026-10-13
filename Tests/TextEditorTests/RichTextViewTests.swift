import SwiftUI
import XCTest
@testable import TextEditor

@MainActor
final class RichTextViewTests: XCTestCase {
    private var textView: RichTextView!
    private var context: RichTextContext!

    override func setUp() async throws {
        textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        context = RichTextContext()
        context.textView = textView
        textView.context = context
    }

    private var isBold: Bool {
        RichTextFormatter.isStyle(.bold, activeIn: textView.textStorage, range: NSRange(location: 0, length: 5), defaultFont: textView.defaultFont)
    }

    func testUsesTextKit2() {
        XCTAssertNotNil(textView.textLayoutManager)
    }

    func testFormattingSelectionKeepsSelectionAndIsUndoable() {
        textView.setContent(NSAttributedString(string: "Hello world"))
        textView.selectedRange = NSRange(location: 0, length: 5)

        context.toggle(.bold)
        XCTAssertTrue(isBold)
        XCTAssertEqual(textView.selectedRange, NSRange(location: 0, length: 5))
        XCTAssertTrue(context.isActive(.bold))

        context.undo()
        XCTAssertFalse(isBold)
        XCTAssertEqual(textView.textStorage.string, "Hello world")

        context.redo()
        XCTAssertTrue(isBold)
    }

    func testFormattingWithCaretOnlyChangesTypingAttributes() {
        textView.setContent(NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 5, length: 0)

        context.toggle(.italic)

        let typingFont = textView.typingAttributes[.font] as! UIFont
        XCTAssertTrue(typingFont.hasTrait(.traitItalic))
        XCTAssertTrue(context.isActive(.italic))
        XCTAssertFalse(textView.undoManager!.canUndo)
    }

    func testAdjustFontSizeUpdatesContext() {
        textView.setContent(NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        let initialSize = textView.defaultFont.pointSize

        context.adjustFontSize(by: 1)

        XCTAssertEqual(context.fontSize, initialSize + 1)
    }

    func testAlignmentAppliesToCurrentParagraph() {
        textView.setContent(NSAttributedString(string: "one\ntwo"))
        textView.selectedRange = NSRange(location: 5, length: 0)

        context.setAlignment(.center)

        let first = textView.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let second = textView.textStorage.attribute(.paragraphStyle, at: 4, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotEqual(first?.alignment, .center)
        XCTAssertEqual(second?.alignment, .center)
        XCTAssertEqual(context.alignment, .center)
    }

    func testInsertImageAtCaretIsUndoable() {
        textView.setContent(NSAttributedString(string: "ab"))
        textView.selectedRange = NSRange(location: 1, length: 0)
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000)).image { _ in }

        context.insertImage(photo)

        let attachment = textView.textStorage.attribute(.attachment, at: 1, effectiveRange: nil) as? NSTextAttachment
        XCTAssertEqual(textView.textStorage.length, 3)
        XCTAssertEqual(attachment?.image?.size.width, 320)
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))

        context.undo()
        XCTAssertEqual(textView.textStorage.string, "ab")
    }

    func testPlaceholderShowsOnlyWhenEmpty() {
        textView.placeholder = "Type ..."
        textView.setContent(NSAttributedString())
        XCTAssertFalse(textView.placeholderLabel.isHidden)

        textView.setContent(NSAttributedString(string: "x"))
        XCTAssertTrue(textView.placeholderLabel.isHidden)
    }

    func testLoadingContentAppliesDefaultsAndClearsUndo() {
        textView.setContent(NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 0, length: 5)
        context.toggle(.bold)
        XCTAssertTrue(textView.undoManager!.canUndo)

        textView.setContent(NSAttributedString(string: "New"))

        XCTAssertFalse(textView.undoManager!.canUndo)
        XCTAssertEqual(textView.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, textView.defaultFont)
    }

    // MARK: Binding

    func testEditsArePushedToBinding() {
        var bound = NSAttributedString(string: "Hello")
        let binding = Binding(get: { bound }, set: { bound = $0 })
        let representable = RichTextViewRepresentable(text: binding, editorContext: context, placeholder: "", toolbar: nil)
        let coordinator = representable.makeCoordinator()
        textView.delegate = coordinator
        textView.setContent(bound)

        textView.selectedRange = NSRange(location: 0, length: 5)
        context.toggle(.bold)

        let font = bound.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.hasTrait(.traitBold), true)
        XCTAssertTrue(coordinator.lastSyncedText === bound)
    }
}
