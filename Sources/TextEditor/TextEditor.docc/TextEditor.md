# ``TextEditor``

A rich text editor for SwiftUI, backed by TextKit 2.

## Overview

``RichTextEditor`` edits an `NSAttributedString` through a binding and shows a formatting toolbar above the keyboard. It supports character styles, headings, lists, quotes, code blocks, links, colors and images, with undo for every change and Markdown shortcuts while typing.

Content converts to and from Markdown, HTML and a lossless archive with ``RichTextSerializer``.

```swift
struct NoteView: View {
    @State private var text = NSAttributedString()

    var body: some View {
        ScrollView {
            RichTextEditor(text: $text, placeholder: "Write something…")
                .padding()
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``RichTextEditor``
- ``RichTextContext``

### Formatting

- ``TextStyle``
- ``BlockStyle``

### Toolbar

- <doc:CustomizingTheToolbar>
- ``RichTextToolbar``
- ``RichTextToolbarConfiguration``
- ``EditorSection``
- ``RichTextColor``
- ``RichTextToolbarAction``

### Saving and Loading

- <doc:SavingAndLoading>
- ``RichTextSerializer``
