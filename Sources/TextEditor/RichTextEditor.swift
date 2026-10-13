//
//  RichTextEditor.swift
//
//

import SwiftUI

/// A rich text editor with a formatting toolbar above the keyboard.
///
/// The editor grows with its content; place it in a `ScrollView` for long documents.
public struct RichTextEditor: View {
    @Binding private var text: NSAttributedString
    @StateObject private var internalContext = RichTextContext()

    private let externalContext: RichTextContext?
    private let placeholder: String
    private let toolbar: RichTextToolbarConfiguration?

    /// - Parameters:
    ///   - text: The document. Updated on every edit.
    ///   - context: Pass your own context to read formatting state or drive the editor from custom controls.
    ///   - placeholder: Shown while the document is empty.
    ///   - toolbar: Toolbar sections in display order. Pass an empty array to hide the toolbar.
    public init(
        text: Binding<NSAttributedString>,
        context: RichTextContext? = nil,
        placeholder: String = "Type ...",
        toolbar sections: [EditorSection] = EditorSection.allCases
    ) {
        self.init(
            text: text,
            context: context,
            placeholder: placeholder,
            toolbar: sections.isEmpty ? nil : RichTextToolbarConfiguration(sections: sections)
        )
    }

    /// - Parameters:
    ///   - toolbar: The keyboard toolbar's configuration, or `nil` for no keyboard toolbar.
    public init(
        text: Binding<NSAttributedString>,
        context: RichTextContext? = nil,
        placeholder: String = "Type ...",
        toolbar configuration: RichTextToolbarConfiguration?
    ) {
        self._text = text
        self.externalContext = context
        self.placeholder = placeholder
        self.toolbar = configuration
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

struct RichTextViewRepresentable: UIViewRepresentable {
    @Binding var text: NSAttributedString
    let editorContext: RichTextContext
    let placeholder: String
    let toolbar: RichTextToolbarConfiguration?

    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.setContent(text)
        context.coordinator.lastSyncedText = text
        connect(textView)
        updateToolbar(of: textView)
        return textView
    }

    func updateUIView(_ textView: RichTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        textView.placeholder = placeholder

        if editorContext.textView !== textView {
            connect(textView)
        }
        updateToolbar(of: textView)

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
    private func updateToolbar(of textView: RichTextView) {
        let host = textView.inputAccessoryView as? KeyboardToolbarHost
        if let toolbar {
            let content = RichTextToolbar(context: editorContext, configuration: toolbar)
            if let host {
                host.update(content: content)
                return
            }
            textView.inputAccessoryView = KeyboardToolbarHost(content: content)
        } else {
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
            textView.invalidateIntrinsicContentSize()
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
