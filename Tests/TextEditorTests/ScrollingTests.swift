import XCTest
@testable import TextEditor

@MainActor
final class ScrollingTests: XCTestCase {
    private let font = UIFont.preferredFont(forTextStyle: .body)

    private func longList(_ count: Int) -> NSAttributedString {
        let markdown = (1...count).map { "\($0). item \($0)" }.joined(separator: "\n")
        return RichTextSerializer.attributedString(markdown: markdown, defaultFont: font)
    }

    func testScrollingEditorOnlyDecoratesNearTheScreen() throws {
        let textView = RichTextView()
        textView.scrollsContent = true
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        textView.setContent(longList(3000))
        textView.layoutIfNeeded()

        XCTAssertTrue(textView.isScrollEnabled)
        let decorations = textView.decorationView.decorations
        XCTAssertGreaterThan(decorations.count, 10)
        XCTAssertLessThan(decorations.count, 200)
        XCTAssertEqual(decorations.first?.kind, .number(1))

        // Jump far down: decorations follow, numbered as if counted from the top.
        let line = try XCTUnwrap(decorations.dropFirst().first).frame.minY - decorations[0].frame.minY
        textView.contentOffset = CGPoint(x: 0, y: line * 2000)
        textView.layoutIfNeeded()
        let visible = textView.decorationView.decorations.filter { $0.frame.intersects(textView.bounds) }
        let first = try XCTUnwrap(visible.first)
        let paragraphIndex = (textView.textStorage.string as NSString).substring(to: first.paragraphLocation)
            .filter { $0 == "\n" }.count
        XCTAssertEqual(first.kind, .number(paragraphIndex + 1))
    }

    func testGrowingEditorDecoratesEverything() {
        let textView = RichTextView()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        textView.setContent(longList(300))
        // SwiftUI grows the view to fit its content.
        textView.frame.size.height = textView.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height
        textView.layoutIfNeeded()
        XCTAssertEqual(textView.decorationView.decorations.count, 300)
        XCTAssertNil(textView.decoratedRegion)
    }
}
