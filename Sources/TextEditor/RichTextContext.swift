//
//  RichTextContext.swift
//
//

import UIKit

/// The bridge between a `RichTextEditor` and any SwiftUI controls.
///
/// Read its published properties to reflect formatting at the current selection,
/// and call its commands to change it. Pass your own instance to `RichTextEditor`
/// to build custom toolbars or menus.
@MainActor
public final class RichTextContext: ObservableObject {
    @Published public private(set) var activeStyles: Set<TextStyle> = []
    @Published public private(set) var fontSize: CGFloat = UIFont.preferredFont(forTextStyle: .body).pointSize
    @Published public private(set) var textColor: UIColor = .label
    @Published public private(set) var alignment: NSTextAlignment = .natural
    @Published public private(set) var blockStyle: BlockStyle = .paragraph
    @Published public private(set) var link: URL?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false

    weak var textView: RichTextView?

    public init() {}

    public func isActive(_ style: TextStyle) -> Bool {
        activeStyles.contains(style)
    }

    public var canIncreaseFontSize: Bool {
        fontSize < RichTextFormatter.fontSizeRange.upperBound
    }

    public var canDecreaseFontSize: Bool {
        fontSize > RichTextFormatter.fontSizeRange.lowerBound
    }

    // MARK: Commands

    public func toggle(_ style: TextStyle) {
        textView?.toggle(style)
    }

    public func adjustFontSize(by delta: CGFloat) {
        textView?.adjustFontSize(by: delta)
    }

    public func setTextColor(_ color: UIColor) {
        textView?.setTextColor(color)
    }

    public func setAlignment(_ alignment: NSTextAlignment) {
        textView?.setAlignment(alignment)
    }

    public func setBlockStyle(_ blockStyle: BlockStyle) {
        textView?.setBlockStyle(blockStyle)
    }

    /// Applies `blockStyle`, or reverts to a plain paragraph if it's already applied.
    public func toggleBlockStyle(_ blockStyle: BlockStyle) {
        textView?.toggleBlockStyle(blockStyle)
    }

    /// Links the selection, or the link under the caret. Pass `nil` to remove the link.
    /// Only http, https, mailto, tel and relative links are accepted.
    public func setLink(_ url: URL?) {
        textView?.setLink(url)
    }

    /// Shows an alert for adding, editing or removing the link at the selection.
    public func presentLinkEditor() {
        textView?.presentLinkEditor()
    }

    public func insertImage(_ image: UIImage) {
        textView?.insertImage(image)
    }

    public func presentImagePicker() {
        textView?.presentImagePicker()
    }

    public func undo() {
        textView?.undoManager?.undo()
    }

    public func redo() {
        textView?.undoManager?.redo()
    }

    public func dismissKeyboard() {
        textView?.resignFirstResponder()
    }

    // MARK: State

    /// Pulls the latest state from the text view. Each property is only assigned when it changes,
    /// so SwiftUI doesn't re-render the toolbar on every keystroke.
    func refresh() {
        guard let textView else {
            return
        }
        let state = textView.formattingState
        update(\.activeStyles, to: state.activeStyles)
        update(\.fontSize, to: state.fontSize)
        update(\.textColor, to: state.textColor)
        update(\.alignment, to: state.alignment)
        update(\.blockStyle, to: state.blockStyle)
        update(\.link, to: state.link)
        update(\.canUndo, to: textView.undoManager?.canUndo ?? false)
        update(\.canRedo, to: textView.undoManager?.canRedo ?? false)
    }

    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RichTextContext, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
