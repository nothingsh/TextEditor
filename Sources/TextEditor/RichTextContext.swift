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
    /// Character styles applied to the whole selection, or to the text typed next when there's only a caret.
    @Published public private(set) var activeStyles: Set<TextStyle> = []
    /// The point size at the start of the selection, or of the text typed next.
    @Published public private(set) var fontSize: CGFloat = UIFont.preferredFont(forTextStyle: .body).pointSize
    /// The text color at the start of the selection, or of the text typed next.
    @Published public private(set) var textColor: UIColor = .label
    /// The alignment of the paragraph at the start of the selection.
    @Published public private(set) var alignment: NSTextAlignment = .natural
    /// The block style shared by every paragraph the selection touches, or `.paragraph` when they differ.
    @Published public private(set) var blockStyle: BlockStyle = .paragraph
    /// The nesting level of the list item at the start of the selection, from 0; 0 outside lists.
    @Published public private(set) var listLevel = 0
    /// Whether the checklist item at the start of the selection is ticked.
    @Published public private(set) var isChecked = false
    /// The link under the caret or at the start of the selection.
    @Published public private(set) var link: URL?
    /// Whether ``undo()`` has anything to undo.
    @Published public private(set) var canUndo = false
    /// Whether ``redo()`` has anything to redo.
    @Published public private(set) var canRedo = false

    weak var textView: RichTextView?

    /// Creates a context that does nothing until it's passed to a ``RichTextEditor``.
    public init() {}

    /// Whether `style` is in ``activeStyles``.
    public func isActive(_ style: TextStyle) -> Bool {
        activeStyles.contains(style)
    }

    /// Whether ``fontSize`` is below the largest size the editor allows, 72 points.
    public var canIncreaseFontSize: Bool {
        fontSize < RichTextFormatter.fontSizeRange.upperBound
    }

    /// Whether ``fontSize`` is above the smallest size the editor allows, 8 points.
    public var canDecreaseFontSize: Bool {
        fontSize > RichTextFormatter.fontSizeRange.lowerBound
    }

    /// Whether ``indentListItems()`` can nest the list item at the selection deeper.
    public var canIndentListItems: Bool {
        blockStyle.isList && listLevel < BlockStyle.maxListLevel
    }

    /// Whether ``outdentListItems()`` can move the list item at the selection out.
    public var canOutdentListItems: Bool {
        blockStyle.isList && listLevel > 0
    }

    // MARK: Commands
    //
    // Commands do nothing until the context is connected to an editor. Each one is a single undo step.

    /// Turns `style` on for the selection, or off when the whole selection already has it.
    /// With only a caret, applies to the text typed next.
    public func toggle(_ style: TextStyle) {
        textView?.toggle(style)
    }

    /// Changes the font size of the selection, or of the text typed next, by `delta` points,
    /// keeping each run's own size and clamping to 8–72 points.
    public func adjustFontSize(by delta: CGFloat) {
        textView?.adjustFontSize(by: delta)
    }

    /// Colors the selection, or the text typed next.
    public func setTextColor(_ color: UIColor) {
        textView?.setTextColor(color)
    }

    /// Aligns every paragraph the selection touches.
    public func setAlignment(_ alignment: NSTextAlignment) {
        textView?.setAlignment(alignment)
    }

    /// Applies `blockStyle` to every paragraph the selection touches.
    public func setBlockStyle(_ blockStyle: BlockStyle) {
        textView?.setBlockStyle(blockStyle)
    }

    /// Applies `blockStyle`, or reverts to a plain paragraph if it's already applied.
    public func toggleBlockStyle(_ blockStyle: BlockStyle) {
        textView?.toggleBlockStyle(blockStyle)
    }

    /// Nests every list item the selection touches one level deeper. Tab and ⌘] do the same.
    /// Paragraphs that aren't list items are left alone.
    public func indentListItems() {
        textView?.indentListItems()
    }

    /// Moves every list item the selection touches one level out. Shift-Tab and ⌘[ do the same.
    public func outdentListItems() {
        textView?.outdentListItems()
    }

    /// Ticks every checklist item the selection touches, or unticks them when they're all ticked.
    /// Tapping a checkbox ticks just that item.
    public func toggleChecklistItems() {
        textView?.toggleChecklistItems()
    }

    /// Links the selection, or relinks the whole link under the caret. Pass `nil` to remove the link.
    /// With a caret outside any link, inserts the URL itself as linked text.
    ///
    /// Only http, https, mailto, tel and relative links are accepted; others are ignored.
    public func setLink(_ url: URL?) {
        textView?.setLink(url)
    }

    /// Shows an alert for adding, editing or removing the link at the selection.
    public func presentLinkEditor() {
        textView?.presentLinkEditor()
    }

    /// Replaces the selection with `image`, scaled down to fit the editor's width.
    public func insertImage(_ image: UIImage) {
        textView?.insertImage(image)
    }

    /// Shows the system photo picker and inserts the chosen image at the selection.
    /// The picker runs out of process, so no photo library permission is needed.
    public func presentImagePicker() {
        textView?.presentImagePicker()
    }

    /// Shows the system find bar, with a replace field when `showingReplace` is true.
    /// On a hardware keyboard, ⌘F, ⌘G and ⌥⌘F do the same.
    public func presentFindNavigator(showingReplace: Bool = false) {
        textView?.presentFindNavigator(showingReplace: showingReplace)
    }

    /// Undoes the last edit, whether typing or formatting.
    public func undo() {
        textView?.editorUndoManager?.undo()
    }

    /// Redoes the last undone edit.
    public func redo() {
        textView?.editorUndoManager?.redo()
    }

    /// Makes the editor first responder, showing the keyboard and toolbar.
    public func focus() {
        textView?.becomeFirstResponder()
    }

    /// Resigns first responder, hiding the keyboard and toolbar.
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
        update(\.listLevel, to: state.listLevel)
        update(\.isChecked, to: state.isChecked)
        update(\.link, to: state.link)
        update(\.canUndo, to: textView.editorUndoManager?.canUndo ?? false)
        update(\.canRedo, to: textView.editorUndoManager?.canRedo ?? false)
    }

    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RichTextContext, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
