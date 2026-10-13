# TextEditor
<img src="https://img.shields.io/badge/PLATFORM-IOS%2016+-lightgray?style=for-the-badge" />&nbsp;&nbsp;&nbsp;<img src="https://img.shields.io/badge/LICENSE-MIT-lightgray?style=for-the-badge" />&nbsp;&nbsp;&nbsp;<img src="https://img.shields.io/badge/MADE WITH-SWIFTUI%20%2B%20TEXTKIT%202-orange?style=for-the-badge" />

A SwiftUI rich text editor backed by `UITextView`, with a formatting toolbar above the keyboard.

<img src="toolbar.png" alt="Preview Image" width="250"/>

## Features

- Bold, italic, underline, strikethrough and inline code, which combine freely and keep the font family
- Headings, bulleted and numbered lists, quotes and code blocks, with Return and Delete behaving as in Notes
- Links, font size, text color and per-paragraph alignment
- Images inserted at the caret through the system photo picker (no permission prompt)
- Markdown, HTML and lossless archive import and export
- Undo and redo for every edit, including formatting; ⌘B, ⌘I and ⌘U on hardware keyboards
- A configurable toolbar whose state follows the selection, with dark mode and VoiceOver support

## Usage

```swift
import SwiftUI
import TextEditor

struct ContentView: View {
    @State private var text = NSAttributedString()

    var body: some View {
        ScrollView {
            RichTextEditor(text: $text, placeholder: "Write something…")
                .padding()
        }
    }
}
```

The editor grows with its content, so place it in a `ScrollView` for long documents.

### Configuring the toolbar

Pick sections in display order, or pass an empty array to hide the toolbar:

```swift
RichTextEditor(text: $text, toolbar: [.textStyle, .blockStyle, .lists, .link, .history])
```

For custom colors or your own buttons, pass a configuration:

```swift
RichTextEditor(text: $text, toolbar: RichTextToolbarConfiguration(
    sections: [.textStyle, .lists, .colorPalette],
    colors: [RichTextColor("Ink", .label), RichTextColor("Brand", .systemIndigo)],
    customActions: [
        RichTextToolbarAction(title: "Quote", systemImage: "text.quote",
                              isActive: { $0.blockStyle == .quote },
                              action: { $0.toggleBlockStyle(.quote) }),
    ]
))
```

To place the toolbar somewhere other than above the keyboard, pass `toolbar: nil` and add `RichTextToolbar(context:configuration:)` yourself.

### Saving and loading

```swift
let markdown = RichTextSerializer.markdown(from: text)
let html = RichTextSerializer.html(from: text)
let data = try RichTextSerializer.archivedData(from: text)

text = RichTextSerializer.attributedString(markdown: markdown)
text = RichTextSerializer.attributedString(html: html)
text = try RichTextSerializer.attributedString(archivedData: data)
```

| Format   | Keeps                                                    | Drops                                |
|----------|----------------------------------------------------------|--------------------------------------|
| Archive  | everything                                               | nothing — use it for drafts          |
| HTML     | blocks, inline styles, links, colors, alignment, images  | font sizes                           |
| Markdown | blocks, bold, italic, strikethrough, code, links, images | underline, colors, sizes, alignment  |

Images are embedded as base64 `data:` URIs in HTML and Markdown.

### Driving the editor from your own controls

`RichTextContext` publishes the formatting at the current selection and exposes the same commands as the toolbar.

```swift
@StateObject private var context = RichTextContext()

var body: some View {
    VStack {
        RichTextEditor(text: $text, context: context, toolbar: [])
        Button("Bold") { context.toggle(.bold) }
            .foregroundColor(context.isActive(.bold) ? .accentColor : .primary)
        Button("Heading") { context.toggleBlockStyle(.heading1) }
    }
}
```

## Installation

Add the package in Xcode via **File › Add Package Dependencies…**, or in `Package.swift`:

```swift
.package(url: "https://github.com/nothingsh/TextEditor", from: "2.0.0")
```

## Migrating from 1.x

- The minimum platform is now iOS 16.
- `RichTextEditor(richText:onCommit:)` is replaced by `RichTextEditor(text:)` with a `Binding<NSAttributedString>`, which updates on every edit. Use `.onChange(of:)` to save.
- `accessory:` is renamed `toolbar:`, and `EditorSection` gains `.history` (undo and redo).
- The public `Color(hex:)` and `UIColor(hex:)` extensions have been removed.

## Roadmap

- [x] Headings, lists, quotes and code
- [x] Links
- [x] HTML and Markdown import and export
- [x] Configurable toolbar items and colors
- [ ] Checklists and nested lists
- [ ] Markdown shortcuts while typing (`# `, `- `, `1. `)
- [ ] Font selection
- [ ] macOS support
