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
    private(set) lazy var checklistTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleChecklistTap(_:)))

    /// UITextView drops custom attributes whenever it recomputes typing attributes. A paragraph format chosen
    /// for an empty paragraph exists nowhere in the text yet, so it's remembered here with its caret location.
    var pendingParagraphFormat: (location: Int, format: ParagraphFormat)?

    /// Whether typed Markdown such as `# ` or `**bold**` turns into formatting.
    var isMarkdownShortcutsEnabled = true

    /// Whether the view scrolls its own content, rather than growing to fit it inside an enclosing scroll view.
    var scrollsContent = false {
        didSet {
            guard scrollsContent != oldValue else {
                return
            }
            isScrollEnabled = scrollsContent
            alwaysBounceVertical = scrollsContent
            keyboardDismissMode = scrollsContent ? .interactive : .none
            setNeedsBlockDecorations()
        }
    }

    /// Undo steps kept in memory; each formatting step holds a copy of the text it changed.
    static let undoLevels = 100

    /// UITextView's own undo manager, which already holds typing history and isn't shared with the window.
    /// Formatting registers here too, so typing and formatting undo in the order they happened.
    var editorUndoManager: UndoManager? {
        super.undoManager
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
            let format = caretParagraphFormat
            state.blockStyle = format.block
            state.listLevel = format.level
            state.isChecked = format.isChecked
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
        addGestureRecognizer(checklistTapRecognizer)
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
        isFindInteractionEnabled = true
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
        editorUndoManager?.levelsOfUndo = Self.undoLevels
        for name in [Notification.Name.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            center.addObserver(self, selector: #selector(undoStateDidChange), name: name, object: editorUndoManager)
        }
    }

    @objc private func textDidChange() {
        syncWritingDirections(in: selectedRange)
        updatePlaceholderVisibility()
        setNeedsBlockDecorations()
        setNeedsCaretScroll()
    }

    private var lastLayoutSize: CGSize = .zero
    private var needsBlockDecorations = false

    /// Several events per keystroke ask for new decorations; they're computed once, at the next layout pass.
    func setNeedsBlockDecorations() {
        needsBlockDecorations = true
        setNeedsLayout()
    }

    /// TextKit 2 only fully lays out text inside the view, so decorations are also recomputed once SwiftUI resizes it.
    override func layoutSubviews() {
        super.layoutSubviews()
        let sizeChanged = bounds.size != lastLayoutSize
        if bounds.width != lastLayoutSize.width {
            fitAttachmentsToWidth()
        }
        if scrollsContent && !decoratedRegionCoversVisibleRegion {
            // Scrolling also lays out; decorations only cover a few screens around what's visible.
            needsBlockDecorations = true
        }
        if sizeChanged || needsBlockDecorations {
            lastLayoutSize = bounds.size
            needsBlockDecorations = false
            updateBlockDecorations()
        }
        if sizeChanged {
            setNeedsCaretScroll()
        }
    }

    // MARK: Visible Region

    private var scrollObservation: NSKeyValueObservation?

    /// The vertical span, in this view's coordinates, that the current decorations were computed for;
    /// `nil` when they cover the whole document.
    var decoratedRegion: ClosedRange<CGFloat>?

    private var decoratedRegionCoversVisibleRegion: Bool {
        guard let region = decoratedRegion else {
            return true
        }
        return region.lowerBound <= max(0, bounds.minY) && region.upperBound >= min(bounds.maxY, contentSize.height)
    }

    /// Decorations only get layers near what's on screen, so follow the enclosing scroll view.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        scrollObservation = enclosingScrollView?.observe(\.contentOffset) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateVisibleDecorationRect()
            }
        }
        updateVisibleDecorationRect()
    }

    func updateVisibleDecorationRect() {
        if scrollsContent {
            decorationView.visibleRect = convert(bounds, to: decorationView)
            return
        }
        guard window != nil, let scrollView = enclosingScrollView else {
            decorationView.visibleRect = nil
            return
        }
        decorationView.visibleRect = scrollView.convert(scrollView.bounds, to: decorationView)
    }

    // MARK: Keeping the Caret Visible

    private var isCaretScrollScheduled = false

    /// The editor grows instead of scrolling, so a new line can land behind the keyboard toolbar. UIKit tries
    /// to reveal the caret while typing, but before SwiftUI has grown the view, when the caret is still out of bounds.
    /// This reveals it again on the next run loop turn, once layout has settled.
    func setNeedsCaretScroll() {
        guard isFirstResponder, !isScrollEnabled, !isCaretScrollScheduled else {
            return
        }
        isCaretScrollScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.isCaretScrollScheduled = false
            self?.scrollCaretToVisible()
        }
    }

    func scrollCaretToVisible() {
        guard isFirstResponder, let position = selectedTextRange?.end, let scrollView = enclosingScrollView else {
            return
        }
        let caret = caretRect(for: position)
        guard !caret.isNull, !caret.isInfinite else {
            return
        }
        // A little margin so the line isn't flush against the toolbar. Not animated, so fast typing never lags behind.
        let target = convert(caret, to: scrollView).insetBy(dx: 0, dy: -12)
        scrollView.scrollRectToVisible(target, animated: false)
    }

    /// Find and replace reveal each match with this. The editor doesn't scroll itself, so reveal it in the enclosing scroll view.
    override func scrollRangeToVisible(_ range: NSRange) {
        guard !isScrollEnabled else {
            super.scrollRangeToVisible(range)
            return
        }
        guard let scrollView = enclosingScrollView,
              let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else {
            return
        }
        let rect = firstRect(for: textRange).union(caretRect(for: end))
        guard !rect.isNull, !rect.isInfinite else {
            return
        }
        scrollView.scrollRectToVisible(convert(rect, to: scrollView).insetBy(dx: 0, dy: -24), animated: true)
    }

    func presentFindNavigator(showingReplace: Bool) {
        if !isFirstResponder {
            becomeFirstResponder()
        }
        findInteraction?.presentFindNavigator(showingReplace: showingReplace)
    }

    /// The nearest scrolling ancestor, such as the `UIScrollView` behind a SwiftUI `ScrollView`.
    var enclosingScrollView: UIScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView, scrollView.isScrollEnabled {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }

    // MARK: Checkboxes

    /// The checklist item whose checkbox is at `point`, in this view's coordinates.
    func checklistItem(at point: CGPoint) -> Int? {
        decorationView.checklistItem(at: convert(point, to: decorationView))
    }

    /// A tap on a checkbox ticks it, and nothing else: no caret placement, which would scroll to the caret
    /// or bring up the keyboard, no selection and no drag. Scrolling can still start on a checkbox.
    ///
    /// Text interaction uses several recognizers, and the one that places the caret isn't a tap recognizer,
    /// so every recognizer but scrolling is held back.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let isOnCheckbox = checklistItem(at: gestureRecognizer.location(in: self)) != nil
        if gestureRecognizer === checklistTapRecognizer {
            return isOnCheckbox
        }
        if isOnCheckbox && !isScrollingGesture(gestureRecognizer) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    func isScrollingGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === panGestureRecognizer || gestureRecognizer === pinchGestureRecognizer
    }

    @objc private func handleChecklistTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let location = checklistItem(at: recognizer.location(in: self)) else {
            return
        }
        toggleChecklistItem(at: location)
        UISelectionFeedbackGenerator().selectionChanged()
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
        pendingParagraphFormat = nil
        if text.length == 0 {
            typingAttributes = defaultAttributes
        }
        editorUndoManager?.removeAllActions()
        syncWritingDirections()
        fitAttachmentsToWidth()
        setNeedsBlockDecorations()
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
        // Encoded once here, so saving and exporting reuse the bytes.
        let attachment = ImageAttachments.attachment(for: image.scaledToFit(width: availableImageWidth))
        let attachmentString = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        // Carry the typing attributes so the line keeps the surrounding font metrics and paragraph style.
        attachmentString.addAttributes(typingAttributes, range: NSRange(location: 0, length: attachmentString.length))

        let range = selectedRange
        let caret = NSRange(location: range.location + attachmentString.length, length: 0)
        replaceCharacters(in: range, with: attachmentString, selecting: caret, actionName: "Insert Image")
    }

    /// Imported images can be wider than the editor; show those scaled to fit, others at their natural size.
    func fitAttachmentsToWidth() {
        guard bounds.width > 0 else {
            return
        }
        let width = availableImageWidth
        var changed = false
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, _, _ in
            guard let attachment = value as? NSTextAttachment, let size = attachment.image?.size, size.width > 0 else {
                return
            }
            let bounds = size.width > width ? CGRect(x: 0, y: 0, width: width, height: (size.height * width / size.width).rounded()) : .zero
            if attachment.bounds != bounds {
                attachment.bounds = bounds
                changed = true
            }
        }
        if changed, let layoutManager = textLayoutManager {
            layoutManager.invalidateLayout(for: layoutManager.documentRange)
        }
    }

    private var availableImageWidth: CGFloat {
        let width = bounds.width - textContainerInset.left - textContainerInset.right - textContainer.lineFragmentPadding * 2
        return width > 0 ? width : 300
    }

    // MARK: Undoable Editing
    //
    // UIKit discards its typing undo history whenever characters in `textStorage` are replaced directly.
    // So attribute-only edits use `setAttributes`, and character edits go through `UITextInput`,
    // which records them alongside typing. Either way typing and formatting undo in the order they happened.

    /// Applies an attribute-only edit to `range` as a single undoable step, keeping the selection.
    func editAttributes(in range: NSRange, actionName: String, _ edit: (NSMutableAttributedString, NSRange) -> Void) {
        let edited = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        edit(edited, NSRange(location: 0, length: edited.length))
        applyAttributes(of: edited, at: range.location, actionName: actionName)
        didEditProgrammatically()
    }

    /// Gives the characters at `location` the attributes of `attributed`, which has the same characters.
    /// Registers the inverse, which in turn registers this, so redo works too.
    private func applyAttributes(of attributed: NSAttributedString, at location: Int, actionName: String) {
        let range = NSRange(location: location, length: attributed.length)
        let original = textStorage.attributedSubstring(from: range)
        textStorage.beginEditing()
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, runRange, _ in
            textStorage.setAttributes(attributes, range: NSRange(location: location + runRange.location, length: runRange.length))
        }
        textStorage.endEditing()

        editorUndoManager?.registerUndo(withTarget: self) { textView in
            textView.applyAttributes(of: original, at: location, actionName: actionName)
            textView.didEditProgrammatically()
        }
        editorUndoManager?.setActionName(actionName)
    }

    /// Replaces the characters in `range` as one undoable step: UIKit inserts the text and records it,
    /// then the replacement's attributes, such as an image attachment, are applied on top.
    func replaceCharacters(in range: NSRange, with replacement: NSAttributedString, selecting newSelection: NSRange, actionName: String) {
        // Commit any in-progress IME composition (e.g. Pinyin) before editing.
        if markedTextRange != nil {
            unmarkText()
        }
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else {
            return
        }
        editorUndoManager?.beginUndoGrouping()
        replace(textRange, withText: replacement.string)
        if replacement.length > 0 {
            applyAttributes(of: replacement, at: range.location, actionName: actionName)
        }
        editorUndoManager?.setActionName(actionName)
        editorUndoManager?.endUndoGrouping()

        selectedRange = newSelection
        didEditProgrammatically()
    }

    /// Programmatic storage edits don't reach the delegate on their own.
    func didEditProgrammatically() {
        syncWritingDirections()
        updatePlaceholderVisibility()
        setNeedsBlockDecorations()
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
