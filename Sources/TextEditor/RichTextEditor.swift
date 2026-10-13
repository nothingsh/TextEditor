//
//  RichTextEditor.swift
//
//

import SwiftUI

/// A rich text editor with a formatting toolbar above the keyboard.
///
/// By default the editor grows with its content; place it in a `ScrollView`. For long documents,
/// use `scrollsContent(_:)` so the editor scrolls itself and only lays out the text on screen.
public struct RichTextEditor: View {
    @Binding private var text: NSAttributedString
    @StateObject private var internalContext = RichTextContext()

    private let externalContext: RichTextContext?
    private let placeholder: String
    private let toolbar: RichTextToolbarConfiguration?

    /// Creates an editor whose keyboard toolbar shows the given sections.
    ///
    /// - Parameters:
    ///   - text: The document. Updated on every edit. Setting it from outside replaces the document and clears undo.
    ///   - context: Pass your own context to read formatting state or drive the editor from custom controls.
    ///   - placeholder: Shown while the document is empty.
    ///   - toolbar: Toolbar sections in display order. Pass an empty array to hide the toolbar.
    public init(
        text: Binding<NSAttributedString>,
        context: RichTextContext? = nil,
        placeholder: String = "Type…",
        toolbar: [EditorSection] = EditorSection.allCases
    ) {
        self.init(
            text: text,
            context: context,
            placeholder: placeholder,
            toolbar: toolbar.isEmpty ? nil : RichTextToolbarConfiguration(sections: toolbar)
        )
    }

    /// Creates an editor with a fully configured keyboard toolbar, such as one with custom colors or actions.
    ///
    /// - Parameters:
    ///   - text: The document. Updated on every edit. Setting it from outside replaces the document and clears undo.
    ///   - context: Pass your own context to read formatting state or drive the editor from custom controls.
    ///   - placeholder: Shown while the document is empty.
    ///   - toolbar: The keyboard toolbar's configuration, or `nil` for no keyboard toolbar.
    public init(
        text: Binding<NSAttributedString>,
        context: RichTextContext? = nil,
        placeholder: String = "Type…",
        toolbar: RichTextToolbarConfiguration?
    ) {
        self._text = text
        self.externalContext = context
        self.placeholder = placeholder
        self.toolbar = toolbar
    }

    public var body: some View {
        RichTextViewRepresentable(
            text: $text,
            editorContext: externalContext ?? internalContext,
            placeholder: placeholder,
            toolbar: toolbar
        )
    }
}

public extension View {
    /// Turns typed Markdown such as `# `, `- ` or `**bold**` into formatting. On by default.
    func markdownShortcuts(_ isEnabled: Bool) -> some View {
        environment(\.isMarkdownShortcutsEnabled, isEnabled)
    }
}

public extension View {
    /// Makes ``RichTextEditor`` scroll its own content and fill the space it's offered, instead of growing
    /// to fit its content inside a `ScrollView`. Off by default.
    ///
    /// Use it for long documents: a growing editor lays out the whole document on every edit,
    /// while a scrolling one only lays out what's on screen. Don't put a scrolling editor in a `ScrollView`.
    func scrollsContent(_ isEnabled: Bool = true) -> some View {
        environment(\.scrollsEditorContent, isEnabled)
    }
}

private struct MarkdownShortcutsKey: EnvironmentKey {
    static let defaultValue = true
}

private struct ScrollsContentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var scrollsEditorContent: Bool {
        get { self[ScrollsContentKey.self] }
        set { self[ScrollsContentKey.self] = newValue }
    }

    var isMarkdownShortcutsEnabled: Bool {
        get { self[MarkdownShortcutsKey.self] }
        set { self[MarkdownShortcutsKey.self] = newValue }
    }
}

struct RichTextViewRepresentable: UIViewRepresentable {
    @Binding var text: NSAttributedString
    let editorContext: RichTextContext
    let placeholder: String
    let toolbar: RichTextToolbarConfiguration?

    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.scrollsContent = context.environment.scrollsEditorContent
        textView.setContent(text)
        context.coordinator.lastSyncedText = text
        connect(textView)
        updateToolbar(of: textView, coordinator: context.coordinator)
        return textView
    }

    func updateUIView(_ textView: RichTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        textView.placeholder = placeholder
        textView.isMarkdownShortcutsEnabled = context.environment.isMarkdownShortcutsEnabled
        textView.scrollsContent = context.environment.scrollsEditorContent

        if editorContext.textView !== textView {
            connect(textView)
        }
        updateToolbar(of: textView, coordinator: coordinator)

        // Skip our own echo: after an edit the binding holds the exact snapshot we pushed.
        guard text !== coordinator.lastSyncedText else {
            return
        }
        coordinator.lastSyncedText = text
        if !text.isEqual(to: textView.textStorage) {
            coordinator.isApplyingExternalChange = true
            textView.setContent(text)
            coordinator.isApplyingExternalChange = false
            refreshAfterViewUpdate()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView textView: RichTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else {
            return nil
        }
        if textView.scrollsContent {
            // Fill the offered space; measuring the content would lay out the whole document.
            guard let height = proposal.height, height.isFinite else {
                return nil
            }
            return CGSize(width: width, height: height)
        }
        let fittingSize = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fittingSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func connect(_ textView: RichTextView) {
        textView.context = editorContext
        editorContext.textView = textView
        refreshAfterViewUpdate()
    }

    /// Reuses the existing host so toolbar state, like an open color palette, survives SwiftUI updates.
    ///
    /// The parent re-renders on every keystroke because the binding changes, so this skips all work
    /// unless the configuration did change; the toolbar itself follows formatting through the context.
    private func updateToolbar(of textView: RichTextView, coordinator: Coordinator) {
        let host = textView.inputAccessoryView as? KeyboardToolbarHost
        if let toolbar {
            if host != nil, let current = coordinator.toolbar, current.isEquivalent(to: toolbar) {
                return
            }
            coordinator.toolbar = toolbar
            let content = RichTextToolbar(context: editorContext, configuration: toolbar)
            if let host {
                host.update(content: content)
                return
            }
            textView.inputAccessoryView = KeyboardToolbarHost(content: content)
        } else {
            coordinator.toolbar = nil
            guard host != nil else {
                return
            }
            textView.inputAccessoryView = nil
        }
        if textView.isFirstResponder {
            textView.reloadInputViews()
        }
    }

    /// Publishing from inside a SwiftUI view update is not allowed, so defer to the next run loop turn.
    private func refreshAfterViewUpdate() {
        let editorContext = editorContext
        DispatchQueue.main.async {
            editorContext.refresh()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextViewRepresentable
        /// The last value pushed to or received from the binding.
        var lastSyncedText: NSAttributedString?
        /// The configuration the keyboard toolbar was last built with.
        var toolbar: RichTextToolbarConfiguration?
        var isApplyingExternalChange = false

        init(_ parent: RichTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange else {
                return
            }
            let snapshot = NSAttributedString(attributedString: textView.textStorage)
            lastSyncedText = snapshot
            parent.text = snapshot
            if !((textView as? RichTextView)?.scrollsContent ?? false) {
                textView.invalidateIntrinsicContentSize()
            }
            parent.editorContext.refresh()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingExternalChange else {
                return
            }
            (textView as? RichTextView)?.selectionDidChange()
            parent.editorContext.refresh()
        }
    }
}

struct RichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        Preview()
    }

    private struct Preview: View {
        @State private var text = NSAttributedString(string: "Hello, rich text.")

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RichTextEditor(text: $text)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary))
                    Text("\(text.length) characters")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}
