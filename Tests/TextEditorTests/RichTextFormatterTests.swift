import XCTest
@testable import TextEditor

final class RichTextFormatterTests: XCTestCase {
    private let avenir = UIFont(name: "AvenirNext-Regular", size: 17)!
    private let defaultColor = UIColor.label

    private func text(_ string: String, font: UIFont? = nil) -> NSMutableAttributedString {
        NSMutableAttributedString(string: string, attributes: [.font: font ?? avenir])
    }

    private func font(in text: NSAttributedString, at index: Int) -> UIFont {
        text.attribute(.font, at: index, effectiveRange: nil) as! UIFont
    }

    private func apply(_ style: TextStyle, enabled: Bool, to text: NSMutableAttributedString, range: NSRange? = nil) {
        RichTextFormatter.transformAttributes(in: text, range: range ?? NSRange(location: 0, length: text.length)) {
            RichTextFormatter.setting(style, enabled: enabled, in: $0, defaultFont: avenir)
        }
    }

    // MARK: Bold & Italic

    func testBoldAndItalicCombineAndKeepFontFamily() {
        let text = text("Hello")
        apply(.bold, enabled: true, to: text)
        apply(.italic, enabled: true, to: text)

        let result = font(in: text, at: 0)
        XCTAssertTrue(result.hasTrait(.traitBold))
        XCTAssertTrue(result.hasTrait(.traitItalic))
        XCTAssertEqual(result.familyName, avenir.familyName)
        XCTAssertEqual(result.pointSize, 17)
    }

    func testRemovingBoldKeepsItalic() {
        let text = text("Hello")
        apply(.bold, enabled: true, to: text)
        apply(.italic, enabled: true, to: text)
        apply(.bold, enabled: false, to: text)

        let result = font(in: text, at: 0)
        XCTAssertFalse(result.hasTrait(.traitBold))
        XCTAssertTrue(result.hasTrait(.traitItalic))
    }

    func testBoldWorksWithSystemTextStyleFont() {
        let body = UIFont.preferredFont(forTextStyle: .body)
        XCTAssertTrue(body.withTrait(.traitBold, enabled: true).hasTrait(.traitBold))
    }

    func testStyleIsActiveOnlyWhenWholeRangeHasIt() {
        let text = text("ab")
        apply(.bold, enabled: true, to: text, range: NSRange(location: 0, length: 1))

        XCTAssertTrue(RichTextFormatter.isStyle(.bold, activeIn: text, range: NSRange(location: 0, length: 1), defaultFont: avenir))
        XCTAssertFalse(RichTextFormatter.isStyle(.bold, activeIn: text, range: NSRange(location: 0, length: 2), defaultFont: avenir))
    }

    // MARK: Underline & Strikethrough

    func testUnderlineAndStrikethroughToggleCleanly() {
        let text = text("Hello")
        apply(.underline, enabled: true, to: text)
        apply(.strikethrough, enabled: true, to: text)
        XCTAssertEqual(text.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(text.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)

        apply(.underline, enabled: false, to: text)
        XCTAssertNil(text.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        XCTAssertNotNil(text.attribute(.strikethroughStyle, at: 0, effectiveRange: nil))
    }

    // MARK: Font Size

    func testAdjustFontSizeKeepsRelativeSizesAndTraits() {
        let text = text("ab")
        text.addAttribute(.font, value: avenir.withSize(10), range: NSRange(location: 0, length: 1))
        text.addAttribute(.font, value: avenir.withSize(20).withTrait(.traitBold, enabled: true), range: NSRange(location: 1, length: 1))

        RichTextFormatter.transformAttributes(in: text, range: NSRange(location: 0, length: 2)) {
            RichTextFormatter.adjustingFontSize(by: 2, in: $0, defaultFont: avenir)
        }

        XCTAssertEqual(font(in: text, at: 0).pointSize, 12)
        XCTAssertEqual(font(in: text, at: 1).pointSize, 22)
        XCTAssertTrue(font(in: text, at: 1).hasTrait(.traitBold))
    }

    func testAdjustFontSizeIsClamped() {
        let large = RichTextFormatter.adjustingFontSize(by: 10, in: [.font: avenir.withSize(70)], defaultFont: avenir)
        let small = RichTextFormatter.adjustingFontSize(by: -10, in: [.font: avenir.withSize(9)], defaultFont: avenir)
        XCTAssertEqual((large[.font] as! UIFont).pointSize, RichTextFormatter.fontSizeRange.upperBound)
        XCTAssertEqual((small[.font] as! UIFont).pointSize, RichTextFormatter.fontSizeRange.lowerBound)
    }

    // MARK: Alignment

    func testAlignmentAppliesToWholeParagraphOnlyAndKeepsLineSpacing() {
        let text = text("one\ntwo")
        let spacing = NSMutableParagraphStyle()
        spacing.lineSpacing = 3
        text.addAttribute(.paragraphStyle, value: spacing, range: NSRange(location: 0, length: text.length))

        let caretInSecondParagraph = NSRange(location: 5, length: 0)
        let range = RichTextFormatter.paragraphRange(in: text, for: caretInSecondParagraph)
        XCTAssertEqual(range, NSRange(location: 4, length: 3))

        RichTextFormatter.setAlignment(.center, in: text, range: range)

        let first = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        let second = text.attribute(.paragraphStyle, at: 4, effectiveRange: nil) as! NSParagraphStyle
        XCTAssertEqual(first.alignment, .natural)
        XCTAssertEqual(second.alignment, .center)
        XCTAssertEqual(second.lineSpacing, 3)
    }

    // MARK: State

    func testStateWithCaretReadsTypingAttributes() {
        let typing: RichTextFormatter.Attributes = [
            .font: avenir.withSize(20).withTrait(.traitItalic, enabled: true),
            .foregroundColor: UIColor.red,
        ]
        let state = RichTextFormatter.state(
            of: text("plain"),
            selection: NSRange(location: 2, length: 0),
            typingAttributes: typing,
            defaultFont: avenir,
            defaultTextColor: defaultColor
        )
        XCTAssertEqual(state.activeStyles, [.italic])
        XCTAssertEqual(state.fontSize, 20)
        XCTAssertEqual(state.textColor, .red)
        XCTAssertEqual(state.alignment, .natural)
    }

    func testStateWithSelectionReadsSelectedText() {
        let text = text("Hello")
        apply(.underline, enabled: true, to: text)
        let state = RichTextFormatter.state(
            of: text,
            selection: NSRange(location: 0, length: 5),
            typingAttributes: [:],
            defaultFont: avenir,
            defaultTextColor: defaultColor
        )
        XCTAssertEqual(state.activeStyles, [.underline])
        XCTAssertEqual(state.textColor, defaultColor)
    }

    // MARK: Defaults

    func testApplyingDefaultsOnlyFillsMissingAttributes() {
        let text = NSMutableAttributedString(string: "ab")
        text.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 1))

        let result = RichTextFormatter.applyingDefaults(to: text, font: avenir, textColor: defaultColor)

        XCTAssertEqual(result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, defaultColor)
        XCTAssertEqual(result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont, avenir)
    }

    // MARK: Images

    func testScaledImageFitsWidthAndKeepsAspectRatio() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000)).image { _ in }
        let scaled = image.scaledToFit(width: 300)
        XCTAssertEqual(scaled.size, CGSize(width: 300, height: 150))

        let small = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { _ in }
        XCTAssertTrue(small.scaledToFit(width: 300) === small)
    }
}
