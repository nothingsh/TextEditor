# Getting Started

Add a rich text editor to a view and react to formatting changes.

## Add the Editor

Bind ``RichTextEditor`` to an `NSAttributedString`. The binding updates on every edit, including formatting changes.

```swift
@State private var text = NSAttributedString()

var body: some View {
    ScrollView {
        RichTextEditor(text: $text, placeholder: "Write something…")
            .padding()
    }
}
```

The editor sizes itself to its content rather than scrolling internally, so place it in a `ScrollView` for long documents.

Setting the binding from outside replaces the document and clears its undo history.

## Format Text

People format text with the toolbar above the keyboard, the B/I/U edit menu, hardware keyboard shortcuts (⌘B, ⌘I, ⌘U), or Markdown typed directly:

| Type at the start of a paragraph | Result          |
|----------------------------------|-----------------|
| `#`, `##`, `###` and a space     | Heading         |
| `-`, `*` or `+` and a space      | Bulleted list   |
| `1.` or `1)` and a space         | Numbered list   |
| `>` and a space                  | Quote           |
| Three backticks and a space      | Code block      |

Wrapping text in `**` or `__` makes it bold, `*` or `_` italic, `~~` strikethrough, and backticks inline code, as soon as the closing marker is typed. Undo brings back the literal Markdown.

Turn this off with the `markdownShortcuts(_:)` view modifier:

```swift
RichTextEditor(text: $text)
    .markdownShortcuts(false)
```

In lists and quotes, Return continues the block, Return on an empty item ends it, and Delete at the start of an item removes its style before joining paragraphs. In code blocks, Return always starts another code line; Delete at the start of a line turns it back into body text. Return at the end of a heading starts a body paragraph.

## Drive the Editor from Your Own Controls

Pass a ``RichTextContext`` to read the formatting at the selection and run the same commands as the toolbar:

```swift
@StateObject private var context = RichTextContext()

var body: some View {
    VStack {
        RichTextEditor(text: $text, context: context, toolbar: [])
        HStack {
            Button("Bold") { context.toggle(.bold) }
                .bold(context.isActive(.bold))
            Button("Heading") { context.toggleBlockStyle(.heading1) }
            Button("Undo") { context.undo() }
                .disabled(!context.canUndo)
        }
    }
}
```

Commands apply to the selection, or to the text typed next when there's only a caret. Paragraph commands such as ``RichTextContext/setBlockStyle(_:)`` and ``RichTextContext/setAlignment(_:)`` apply to every paragraph the selection touches.
