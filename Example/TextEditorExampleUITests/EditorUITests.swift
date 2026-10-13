import XCTest

/// Taps the real app, covering what unit tests can't: gesture recognizers competing for the same touch.
///
/// Checkboxes aren't accessibility elements, so the checklist tests tap where the sample document draws them.
/// The offsets match the sample on a 402-point-wide iPhone, such as iPhone 17 Pro.
final class EditorUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Centres of the sample's two checkboxes, relative to the editor's top-left corner.
    private let tickedCheckbox = CGVector(dx: 10.5, dy: 313)
    private let untickedCheckbox = CGVector(dx: 10.5, dy: 335)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-sampleDocument"]
        app.launch()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
    }

    private var editor: XCUIElement {
        app.textViews.firstMatch
    }

    private var hasKeyboardFocus: Bool {
        (editor.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    private func point(_ offset: CGVector) -> XCUICoordinate {
        editor.coordinate(withNormalizedOffset: .zero).withOffset(offset)
    }

    /// A ticked checkbox is a disc in the tint color; an unticked one is an outline around the background.
    private func isTicked(_ offset: CGVector) throws -> Bool {
        let image = XCUIScreen.main.screenshot().image
        let location = CGPoint(x: editor.frame.minX + offset.dx, y: editor.frame.minY + offset.dy)
        let cgImage = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cgImage.width) / image.size.width
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Sample just off the centre, to miss the checkmark.
        context.draw(cgImage, in: CGRect(
            x: -(location.x - 4) * scale, y: -(CGFloat(cgImage.height) - (location.y + 4) * scale),
            width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)
        ))
        let (red, blue) = (Int(pixel[0]), Int(pixel[2]))
        return blue - red > 80
    }

    func testTappingTextShowsKeyboard() {
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(hasKeyboardFocus)
    }

    func testTappingCheckboxTicksItWithoutFocusing() throws {
        XCTAssertTrue(try isTicked(tickedCheckbox))
        XCTAssertFalse(try isTicked(untickedCheckbox))

        point(untickedCheckbox).tap()
        sleep(1)

        XCTAssertTrue(try isTicked(untickedCheckbox))
        XCTAssertTrue(try isTicked(tickedCheckbox))
        XCTAssertFalse(hasKeyboardFocus, "a checkbox tap shouldn't place the caret")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    /// Neighbouring targets overlap; a tap near the top of one checkbox must not reach the one above.
    func testTappingTopOfCheckboxTicksThatOne() throws {
        point(CGVector(dx: untickedCheckbox.dx, dy: untickedCheckbox.dy - 8)).tap()
        sleep(1)
        XCTAssertTrue(try isTicked(untickedCheckbox))
        XCTAssertTrue(try isTicked(tickedCheckbox))
    }

    func testTappingCheckboxWhileEditingKeepsKeyboard() throws {
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))

        // Let the keyboard finish animating in, so the layout has settled.
        sleep(1)
        point(untickedCheckbox).tap()
        sleep(1)

        XCTAssertTrue(try isTicked(untickedCheckbox))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
    }
}
