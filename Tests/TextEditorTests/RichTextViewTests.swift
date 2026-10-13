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

    func testWideImportedImagesFitTheEditor() throws {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: format).image { _ in }
        let markdown = "![](data:image/jpeg;base64,\(try XCTUnwrap(wide.jpegData(compressionQuality: 0.5)).base64EncodedString()))"

        textView.setContent(RichTextSerializer.attributedString(markdown: markdown))
        textView.layoutIfNeeded()

        let attachment = try XCTUnwrap(textView.textStorage.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
        XCTAssertEqual(attachment.bounds.width, 320)
        XCTAssertEqual(attachment.bounds.height, 160)
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

    // MARK: Undo

    /// Typing and formatting share one history and undo in the order they happened.
    func testTypingAndFormattingUndoInOrder() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        try XCTSkipUnless(textView.becomeFirstResponder(), "Needs a window to become first responder")
        textView.setContent(NSAttributedString())

        func settle() {
            // Typing undo groups close at the end of the run loop turn.
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        textView.insertText("a")
        settle()
        textView.insertImage(UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in })
        settle()
        textView.insertText("b")
        settle()
        XCTAssertTrue(context.canUndo)

        var states: [String] = []
        while textView.undoManager?.canUndo == true {
            textView.undoManager?.undo()
            states.append(textView.textStorage.string)
        }
        XCTAssertEqual(states, ["a\u{FFFC}", "a", ""])

        while textView.undoManager?.canRedo == true {
            textView.undoManager?.redo()
        }
        XCTAssertEqual(textView.textStorage.string, "a\u{FFFC}b")
        XCTAssertNotNil(textView.textStorage.attribute(.attachment, at: 1, effectiveRange: nil), "redo restores the image, not just its placeholder character")
        textView.resignFirstResponder()
    }

    /// Writing direction is derived from text, so syncing it must not cost the user their typing history.
    func testTypingUndoSurvivesWritingDirectionSync() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        try XCTSkipUnless(textView.becomeFirstResponder(), "Needs a window to become first responder")
        textView.setContent(RichTextSerializer.attributedString(markdown: "- item"))
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)

        for character in " عربي" {
            textView.insertText(String(character))
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertEqual(textView.textStorage.string, "item عربي")

        while textView.undoManager?.canUndo == true {
            textView.undoManager?.undo()
        }
        XCTAssertEqual(textView.textStorage.string, "item")
        textView.resignFirstResponder()
    }

    func testUndoHistoryIsBounded() {
        XCTAssertEqual(textView.undoManager?.levelsOfUndo, RichTextView.undoLevels)
    }

    // MARK: Scrolling

    /// The editor grows instead of scrolling, so the enclosing scroll view must follow the caret.
    func testCaretAtEndIsScrolledIntoEnclosingScrollView() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        let scrollView = UIScrollView(frame: window.bounds)
        window.addSubview(scrollView)
        window.makeKeyAndVisible()

        textView.setContent(NSAttributedString(string: (1...40).map { "line \($0)" }.joined(separator: "\n")))
        let height = textView.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: height)
        scrollView.addSubview(textView)
        scrollView.contentSize = textView.frame.size
        try XCTSkipUnless(textView.becomeFirstResponder(), "Needs a window to become first responder")

        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
        textView.scrollCaretToVisible()

        let caret = textView.convert(textView.caretRect(for: textView.endOfDocument), to: scrollView)
        XCTAssertGreaterThan(scrollView.contentOffset.y, 0)
        // The caret rect overhangs the last line slightly, and scrolling stops at the end of the content.
        XCTAssertLessThanOrEqual(caret.midY, scrollView.contentOffset.y + scrollView.bounds.height)
        textView.resignFirstResponder()
    }

    // MARK: Toolbar

    func testToolbarConfigurationEquivalence() {
        let base = RichTextToolbarConfiguration(sections: [.textStyle], customActions: [
            RichTextToolbarAction(title: "Quote", systemImage: "text.quote") { _ in },
        ])
        var sameButNewClosure = base
        sameButNewClosure.customActions = [RichTextToolbarAction(title: "Quote", systemImage: "text.quote") { $0.undo() }]
        var differentSections = base
        differentSections.sections = [.textStyle, .lists]
        var differentColors = base
        differentColors.colors = [RichTextColor("Ink", .label)]
        var withoutFade = base
        withoutFade.showsScrollEdgeFade = false

        XCTAssertTrue(base.isEquivalent(to: sameButNewClosure))
        XCTAssertFalse(base.isEquivalent(to: differentSections))
        XCTAssertFalse(base.isEquivalent(to: differentColors))
        XCTAssertFalse(base.isEquivalent(to: withoutFade), "toggling the fade must rebuild the keyboard toolbar")
    }

    func testToolbarScrollOverflow() {
        // A row that fits never fades.
        XCTAssertEqual(ToolbarScrollOverflow(offset: 0, contentWidth: 300, viewportWidth: 320), ToolbarScrollOverflow())
        // At the start of a long row, only the trailing edge has more.
        XCTAssertEqual(ToolbarScrollOverflow(offset: 0, contentWidth: 600, viewportWidth: 320).trailing, true)
        XCTAssertEqual(ToolbarScrollOverflow(offset: 0, contentWidth: 600, viewportWidth: 320).leading, false)
        // In the middle, both; at the end, only leading.
        XCTAssertEqual(ToolbarScrollOverflow(offset: 100, contentWidth: 600, viewportWidth: 320), {
            var overflow = ToolbarScrollOverflow(); overflow.leading = true; overflow.trailing = true; return overflow
        }())
        XCTAssertEqual(ToolbarScrollOverflow(offset: 280, contentWidth: 600, viewportWidth: 320).trailing, false)
        // Offsets are measured from the leading edge, which is on the right in right-to-left layouts.
        let atStart = ToolbarScrollOverflow(offset: 0, contentWidth: 600, viewportWidth: 320)
        XCTAssertTrue(atStart.edges(in: .leftToRight) == (left: false, right: true))
        XCTAssertTrue(atStart.edges(in: .rightToLeft) == (left: true, right: false))
        // Before the viewport is measured, nothing fades.
        XCTAssertEqual(ToolbarScrollOverflow(offset: 0, contentWidth: 600, viewportWidth: 0), ToolbarScrollOverflow())
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

    // MARK: Keyboard and Find

    func testKeyCommandsAreUniqueAndListed() {
        let commands = textView.keyCommands ?? []
        let editorCommands = commands.filter { $0.action == #selector(RichTextView.performEditorKeyCommand(_:)) }
        XCTAssertEqual(editorCommands.count, EditorKeyCommand.allCases.count)
        let shortcuts = Set(editorCommands.map { "\($0.modifierFlags.rawValue)-\($0.input ?? "")" })
        XCTAssertEqual(shortcuts.count, editorCommands.count)
    }

    func testKeyCommandsFormat() {
        textView.setContent(NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 0, length: 5)

        textView.perform(.heading2)
        XCTAssertEqual(context.blockStyle, .heading2)
        textView.perform(.heading2)
        XCTAssertEqual(context.blockStyle, .paragraph)

        textView.perform(.strikethrough)
        XCTAssertTrue(context.isActive(.strikethrough))
        textView.perform(.numberedList)
        XCTAssertEqual(context.blockStyle, .numberedList)
        textView.perform(.body)
        XCTAssertEqual(context.blockStyle, .paragraph)
    }

    func testFindInteractionIsEnabled() {
        XCTAssertTrue(textView.isFindInteractionEnabled)
        XCTAssertNotNil(textView.findInteraction)
    }
}
