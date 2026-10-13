//
//  RichTextView.swift
//
//

import UIKit

/// The `UITextView` behind `RichTextEditor`.
///
/// Every formatting command edits `textStorage` in place and registers its inverse with the undo manager,
/// so the selection and undo history survive formatting changes.
final class RichTextView: UITextView {
    let defaultFont: UIFont
    let defaultTextColor: UIColor

    weak var context: RichTextContext?

    let placeholderLabel = UILabel()
    let decorationView = BlockDecorationView()

    /// UITextView drops custom attributes whenever it recomputes typing attributes. A block style chosen
    /// for an empty paragraph exists nowhere in the text yet, so it's remembered here with its caret location.
    var pendingBlockStyle: (location: Int, style: BlockStyle)?

    /// Owned by the editor so its history isn't shared with other text fields in the window.
    private let editorUndoManager = UndoManager()

    override var undoManager: UndoManager? {
        editorUndoManager
    }

    override var attributedText: NSAttributedString! {
        didSet {
            updatePlaceholderVisibility()
        }
    }

    var placeholder: String? {
        get { placeholderLabel.text }
        set {
            placeholderLabel.text = newValue
            accessibilityHint = newValue
        }
    }

    var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: defaultFont, .foregroundColor: defaultTextColor]
    }

    var formattingState: FormattingState {
        var state = RichTextFormatter.state(
            of: textStorage,
            selection: selectedRange,
            typingAttributes: typingAttributes,
            defaultFont: defaultFont,
            defaultTextColor: defaultTextColor
        )
        if selectedRange.length == 0 && isCaretInEmptyParagraph {
            state.blockStyle = caretBlockStyle
        }
        return state
    }

    init(defaultFont: UIFont = .preferredFont(forTextStyle: .body), defaultTextColor: UIColor = .label) {
        self.defaultFont = defaultFont
        self.defaultTextColor = defaultTextColor
        super.init(frame: .zero, textContainer: nil)

        setUpTextView()
        setUpPlaceholder()
        insertSubview(decorationView, at: 0)
        observeChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpTextView() {
        backgroundColor = .clear
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        typingAttributes = defaultAttributes
        // Enables the B/I/U edit menu and ⌘B/⌘I/⌘U, routed to our own undoable commands below.
        allowsEditingTextAttributes = true
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setUpPlaceholder() {
        placeholderLabel.font = defaultFont
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isAccessibilityElement = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: frameLayoutGuide.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
        ])
    }

    private func observeChanges() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: self)
        // Typing undo groups close at the end of the run loop, after the delegate has already fired,
        // so undo availability is refreshed from the undo manager's own notifications.
        for name in [Notification.Name.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            center.addObserver(self, selector: #selector(undoStateDidChange), name: name, object: editorUndoManager)
        }
    }

    @objc private func textDidChange() {
        updatePlaceholderVisibility()
        updateBlockDecorations()
    }

    private var lastLayoutSize: CGSize = .zero

    /// TextKit 2 only fully lays out text inside the view, so decorations are recomputed once SwiftUI resizes it.
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastLayoutSize {
            lastLayoutSize = bounds.size
            updateBlockDecorations()
        }
    }

    // MARK: Standard Edit Actions

    override func toggleBoldface(_ sender: Any?) {
        toggle(.bold)
    }

    override func toggleItalics(_ sender: Any?) {
        toggle(.italic)
    }

    override func toggleUnderline(_ sender: Any?) {
        toggle(.underline)
    }

    @objc private func undoStateDidChange() {
        context?.refresh()
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = textStorage.length > 0
    }

    // MARK: Content

    /// Replaces the whole document, e.g. when the bound value changes outside the editor.
    /// Undo history is cleared because its ranges no longer describe this text.
    func setContent(_ text: NSAttributedString) {
        let caret = min(selectedRange.location, text.length)
        attributedText = RichTextFormatter.applyingDefaults(to: text, font: defaultFont, textColor: defaultTextColor)
        selectedRange = NSRange(location: caret, length: 0)
        pendingBlockStyle = nil
        if text.length == 0 {
            typingAttributes = defaultAttributes
        }
        editorUndoManager.removeAllActions()
        updateBlockDecorations()
    }

    // MARK: Formatting

    func toggle(_ style: TextStyle) {
        let enabled: Bool
        if selectedRange.length > 0 {
            enabled = !RichTextFormatter.isStyle(style, activeIn: textStorage, range: selectedRange, defaultFont: defaultFont)
        } else {
            enabled = !RichTextFormatter.isStyle(style, activeIn: typingAttributes, defaultFont: defaultFont)
        }
        applyFormatting(actionName: style.actionName) { attributes in
            RichTextFormatter.setting(style, enabled: enabled, in: attributes, defaultFont: defaultFont)
        }
    }

    func adjustFontSize(by delta: CGFloat) {
        applyFormatting(actionName: "Font Size") { attributes in
            RichTextFormatter.adjustingFontSize(by: delta, in: attributes, defaultFont: defaultFont)
        }
    }

    func setTextColor(_ color: UIColor) {
        applyFormatting(actionName: "Text Color") { attributes in
            RichTextFormatter.setting(textColor: color, in: attributes)
        }
    }

    /// Alignment is a paragraph attribute, so it applies to every paragraph the selection touches.
    func setAlignment(_ alignment: NSTextAlignment) {
        typingAttributes = RichTextFormatter.setting(alignment: alignment, in: typingAttributes)
        let range = RichTextFormatter.paragraphRange(in: textStorage, for: selectedRange)
        guard range.length > 0 else {
            // An empty trailing paragraph only exists in the typing attributes.
            context?.refresh()
            return
        }
        editAttributes(in: range, actionName: "Alignment") { text, range in
            RichTextFormatter.setAlignment(alignment, in: text, range: range)
        }
    }

    /// With a caret, the change applies to text typed next; with a selection, to the selected text.
    private func applyFormatting(actionName: String, _ transform: (RichTextFormatter.Attributes) -> RichTextFormatter.Attributes) {
        guard selectedRange.length > 0 else {
            typingAttributes = transform(typingAttributes)
            context?.refresh()
            return
        }
        editAttributes(in: selectedRange, actionName: actionName) { text, range in
            RichTextFormatter.transformAttributes(in: text, range: range, transform)
        }
    }

    // MARK: Images

    func insertImage(_ image: UIImage) {
        let attachment = NSTextAttachment(image: image.scaledToFit(width: availableImageWidth))
        let attachmentString = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        // Carry the typing attributes so the line keeps the surrounding font metrics and paragraph style.
        attachmentString.addAttributes(typingAttributes, range: NSRange(location: 0, length: attachmentString.length))

        let range = selectedRange
        let caret = NSRange(location: range.location + attachmentString.length, length: 0)
        replace(range, with: attachmentString, selecting: caret, actionName: "Insert Image")
    }

    private var availableImageWidth: CGFloat {
        let width = bounds.width - textContainerInset.left - textContainerInset.right - textContainer.lineFragmentPadding * 2
        return width > 0 ? width : 300
    }

    // MARK: Undoable Editing

    /// Applies an attribute-only edit to `range` as a single undoable step, keeping the selection.
    func editAttributes(in range: NSRange, actionName: String, _ edit: (NSMutableAttributedString, NSRange) -> Void) {
        let edited = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        edit(edited, NSRange(location: 0, length: edited.length))
        replace(range, with: edited, selecting: selectedRange, actionName: actionName)
    }

    /// Replaces `range` through `textStorage` and registers the inverse replacement with the undo manager.
    /// Redo needs no extra work: while undoing, the inverse registers its own inverse.
    func replace(_ range: NSRange, with replacement: NSAttributedString, selecting newSelection: NSRange, actionName: String) {
        // Commit any in-progress IME composition (e.g. Pinyin) before touching storage.
        if markedTextRange != nil {
            unmarkText()
        }

        let original = textStorage.attributedSubstring(from: range)
        let originalSelection = selectedRange
        let replacedRange = NSRange(location: range.location, length: replacement.length)

        textStorage.replaceCharacters(in: range, with: replacement)
        selectedRange = newSelection

        editorUndoManager.registerUndo(withTarget: self) { textView in
            textView.replace(replacedRange, with: original, selecting: originalSelection, actionName: actionName)
        }
        editorUndoManager.setActionName(actionName)

        // Programmatic storage edits don't reach the delegate on their own.
        updatePlaceholderVisibility()
        updateBlockDecorations()
        delegate?.textViewDidChange?(self)
        context?.refresh()
    }
}

private extension TextStyle {
    var actionName: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .underline: return "Underline"
        case .strikethrough: return "Strikethrough"
        case .code: return "Code"
        }
    }
}
