import XCTest
@testable import TextEditor

@MainActor
final class ListTests: XCTestCase {
    private let font = UIFont.preferredFont(forTextStyle: .body)
    private var textView: RichTextView!
    private var context: RichTextContext!

    override func setUp() async throws {
        textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        context = RichTextContext()
        context.textView = textView
        textView.context = context
    }

    private func type(_ text: String) {
        for character in text {
            textView.insertText(String(character))
            RunLoop.current.run(until: Date())
        }
    }

    private func formats(_ text: NSAttributedString? = nil) -> [ParagraphFormat] {
        let text = text ?? textView.textStorage
        return RichTextFormatter.paragraphRanges(in: text, range: NSRange(location: 0, length: text.length))
            .map { RichTextFormatter.paragraphFormat(of: text, at: $0.location) }
    }

    private var decorations: [BlockDecorationView.Decoration] {
        textView.layoutIfNeeded()
        return textView.decorationView.decorations
    }

    private func headIndent(at location: Int) -> CGFloat? {
        (textView.textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent
    }

    // MARK: Numbering

    func testNumberingCountsEachLevelSeparately() {
        var numbering = ListNumbering()
        let sequence: [ParagraphFormat] = [
            .init(block: .numberedList), .init(block: .numberedList, level: 1), .init(block: .numberedList, level: 1),
            .init(block: .numberedList), .init(block: .bulletList, level: 1), .init(block: .numberedList, level: 1),
            .init(block: .bulletList), .init(block: .numberedList), .paragraph, .init(block: .numberedList),
        ]
        XCTAssertEqual(sequence.map { numbering.next($0) }, [1, 1, 2, 2, 0, 1, 0, 1, 0, 1])
    }

    // MARK: Nesting

    func testIndentAndOutdentListItems() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- a\n- b\n\nplain", defaultFont: font))
        textView.selectedRange = NSRange(location: 2, length: 0)

        context.indentListItems()
        XCTAssertEqual(context.listLevel, 1)
        XCTAssertEqual(headIndent(at: 2), BlockStyle.bulletList.indent + BlockStyle.levelIndent)
        XCTAssertEqual(decorations.map(\.kind), [.bullet(level: 0), .bullet(level: 1)])

        for _ in 0..<10 {
            context.indentListItems()
        }
        XCTAssertEqual(context.listLevel, BlockStyle.maxListLevel)
        XCTAssertFalse(context.canIndentListItems)

        context.outdentListItems()
        XCTAssertEqual(context.listLevel, BlockStyle.maxListLevel - 1)

        // Plain paragraphs aren't nested.
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
        context.indentListItems()
        XCTAssertEqual(formats().last, .paragraph)
        XCTAssertFalse(context.canIndentListItems)
    }

    func testIndentIsUndoable() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- a", defaultFont: font))
        textView.selectedRange = NSRange(location: 1, length: 0)
        context.indentListItems()
        XCTAssertEqual(formats(), [ParagraphFormat(block: .bulletList, level: 1)])
        context.undo()
        XCTAssertEqual(formats(), [ParagraphFormat(block: .bulletList)])
    }

    func testChangingListStyleKeepsLevel() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- a\n  - b", defaultFont: font))
        XCTAssertEqual(formats()[1], ParagraphFormat(block: .bulletList, level: 1))
        textView.selectedRange = NSRange(location: 3, length: 0)
        context.setBlockStyle(.numberedList)
        XCTAssertEqual(formats()[1], ParagraphFormat(block: .numberedList, level: 1))
        context.setBlockStyle(.quote)
        XCTAssertEqual(formats()[1], ParagraphFormat(block: .quote))
    }

    func testTabNestsAndReturnContinuesAtSameLevel() {
        textView.setContent(NSAttributedString())
        type("- a\n\tb\nc")
        XCTAssertEqual(textView.textStorage.string, "a\nb\nc")
        XCTAssertEqual(formats(), [
            ParagraphFormat(block: .bulletList),
            ParagraphFormat(block: .bulletList, level: 1),
            ParagraphFormat(block: .bulletList, level: 1),
        ])
    }

    func testTabOutsideListTypesTab() {
        textView.setContent(NSAttributedString())
        type("a\tb")
        XCTAssertEqual(textView.textStorage.string, "a\tb")
    }

    func testReturnOnEmptyNestedItemOutdentsBeforeEndingList() {
        textView.setContent(NSAttributedString())
        type("- a\n\tb\n\n")
        XCTAssertEqual(context.blockStyle, .bulletList)
        XCTAssertEqual(context.listLevel, 0)
        type("\n")
        XCTAssertEqual(context.blockStyle, .paragraph)
    }

    func testDeleteAtStartOfNestedItemOutdentsFirst() {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- a\n  - b", defaultFont: font))
        textView.selectedRange = NSRange(location: 2, length: 0)
        textView.deleteBackward()
        XCTAssertEqual(formats()[1], ParagraphFormat(block: .bulletList))
        textView.deleteBackward()
        XCTAssertEqual(formats()[1], .paragraph)
        XCTAssertEqual(textView.textStorage.string, "a\nb")
    }

    // MARK: Checklists

    func testChecklistItemsTickAndUntick() {
        textView.setContent(NSAttributedString(string: "milk\neggs"))
        textView.selectedRange = NSRange(location: 0, length: 9)
        context.setBlockStyle(.checklist)
        XCTAssertEqual(decorations.map(\.kind), [.checkbox(isChecked: false), .checkbox(isChecked: false)])

        textView.toggleChecklistItem(at: 5)
        XCTAssertEqual(formats().map(\.isChecked), [false, true])

        // Each step is its own undo group, as it would be when tapped.
        RunLoop.current.run(until: Date())
        context.toggleChecklistItems()
        XCTAssertEqual(formats().map(\.isChecked), [true, true])
        RunLoop.current.run(until: Date())
        context.toggleChecklistItems()
        XCTAssertEqual(formats().map(\.isChecked), [false, false])

        context.undo()
        XCTAssertEqual(formats().map(\.isChecked), [true, true])
    }

    func testReturnAfterTickedItemStartsUnticked() {
        textView.setContent(NSAttributedString())
        type("[x] done\nnext")
        XCTAssertEqual(textView.textStorage.string, "done\nnext")
        XCTAssertEqual(formats(), [ParagraphFormat(block: .checklist, isChecked: true), ParagraphFormat(block: .checklist)])
    }

    func testCheckboxShortcutsFromParagraphAndBullet() {
        textView.setContent(NSAttributedString())
        type("[] a\n")
        textView.insertText("\n")
        type("- [ ] b")
        XCTAssertEqual(textView.textStorage.string, "a\nb")
        XCTAssertEqual(formats(), [ParagraphFormat(block: .checklist), ParagraphFormat(block: .checklist)])
    }

    func testTappingCheckboxTicksIt() throws {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- [ ] task", defaultFont: font))
        let decoration = try XCTUnwrap(decorations.first)
        let box = textView.decorationView.checkboxFrame(for: decoration)
        let center = textView.convert(CGPoint(x: box.midX, y: box.midY), from: textView.decorationView)

        XCTAssertEqual(textView.checklistItem(at: center), 0)
        XCTAssertNil(textView.checklistItem(at: CGPoint(x: 200, y: center.y)))
        XCTAssertTrue(textView.gestureRecognizers?.contains(textView.checklistTapRecognizer) ?? false)    }

    func testNeighbouringCheckboxTargetsDontOverlap() throws {
        textView.setContent(RichTextSerializer.attributedString(markdown: "- [ ] one\n- [ ] two\n- [ ] three", defaultFont: font))
        let items = decorations
        XCTAssertEqual(items.count, 3)
        for item in items {
            let box = textView.decorationView.checkboxFrame(for: item)
            for y in [box.minY + 1, box.midY, box.maxY - 1] {
                XCTAssertEqual(textView.decorationView.checklistItem(at: CGPoint(x: box.midX, y: y)), item.paragraphLocation,
                               "y \(y) in the box of the item at \(item.paragraphLocation)")
            }
        }
    }

    func testOnlyScrollingCanStartOnACheckbox() {
        // Caret placement on iOS 17 and later uses a recognizer that isn't a tap recognizer.
        let textInteraction = (textView.gestureRecognizers ?? []).filter {
            $0 !== textView.checklistTapRecognizer && !textView.isScrollingGesture($0)
        }
        XCTAssertFalse(textInteraction.isEmpty)
        XCTAssertTrue(textView.isScrollingGesture(textView.panGestureRecognizer))
    }

    // MARK: Serialization

    func testMarkdownRoundTripsNestedListsAndTasks() {
        let markdown = "- a\n  - b\n    1. c\n    2. d\n- [x] done\n  - [ ] todo"
        let text = RichTextSerializer.attributedString(markdown: markdown, defaultFont: font)
        XCTAssertEqual(text.string, "a\nb\nc\nd\ndone\ntodo")
        XCTAssertEqual(formats(text), [
            ParagraphFormat(block: .bulletList),
            ParagraphFormat(block: .bulletList, level: 1),
            ParagraphFormat(block: .numberedList, level: 2),
            ParagraphFormat(block: .numberedList, level: 2),
            ParagraphFormat(block: .checklist, isChecked: true),
            ParagraphFormat(block: .checklist, level: 1),
        ])
        XCTAssertEqual(RichTextSerializer.markdown(from: text, defaultFont: font), markdown)
    }

    func testNumberedParentIndentsChildrenPastItsMarker() {
        let text = RichTextSerializer.attributedString(markdown: "1. a\n   - b", defaultFont: font)
        XCTAssertEqual(formats(text), [ParagraphFormat(block: .numberedList), ParagraphFormat(block: .bulletList, level: 1)])
        XCTAssertEqual(RichTextSerializer.markdown(from: text, defaultFont: font), "1. a\n   - b")
    }

    func testHTMLNestsListsInsideItems() {
        let text = RichTextSerializer.attributedString(markdown: "- a\n  1. b\n- [x] c", defaultFont: font)
        let html = RichTextSerializer.html(from: text, defaultFont: font)
        XCTAssertEqual(html, """
        <ul>
        <li>a
        <ol>
        <li>b</li>
        </ol>
        </li>
        <li><input type="checkbox" disabled checked> c</li>
        </ul>
        """)
        let read = RichTextSerializer.attributedString(html: html, defaultFont: font)
        XCTAssertEqual(read.string, "a\nb\nc")
        XCTAssertEqual(formats(read), formats(text))
    }

    func testHTMLChangingListStyleAtSameLevelStartsNewList() {
        let text = RichTextSerializer.attributedString(markdown: "- a\n\n1. b", defaultFont: font)
        XCTAssertEqual(RichTextSerializer.html(from: text, defaultFont: font), "<ul>\n<li>a</li>\n</ul>\n<ol>\n<li>b</li>\n</ol>")
    }

    func testArchiveKeepsLevelsAndCheckboxes() throws {
        let text = RichTextSerializer.attributedString(markdown: "- [x] a\n  - b", defaultFont: font)
        let restored = try RichTextSerializer.attributedString(archivedData: RichTextSerializer.archivedData(from: text))
        XCTAssertEqual(formats(restored), formats(text))
    }

    func testPastedRTFListsKeepTheirNesting() {
        let foreign = NSMutableAttributedString()
        let outer = NSMutableParagraphStyle()
        outer.textLists = [NSTextList(markerFormat: .disc, options: 0)]
        let inner = NSMutableParagraphStyle()
        inner.textLists = [NSTextList(markerFormat: .disc, options: 0), NSTextList(markerFormat: .decimal, options: 0)]
        foreign.append(NSAttributedString(string: "\t•\ta\n", attributes: [.font: font, .paragraphStyle: outer]))
        foreign.append(NSAttributedString(string: "\t1.\tb", attributes: [.font: font, .paragraphStyle: inner]))

        let text = PastedText.normalized(foreign: foreign, defaultFont: font, textColor: .label)
        XCTAssertEqual(text.string, "a\nb")
        XCTAssertEqual(formats(text), [ParagraphFormat(block: .bulletList), ParagraphFormat(block: .numberedList, level: 1)])
    }
}
