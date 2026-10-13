# Customizing the Toolbar

Choose toolbar controls, offer your own colors and buttons, or place the toolbar anywhere.

## Choose Sections

Pass ``EditorSection`` values in display order:

```swift
RichTextEditor(text: $text, toolbar: [.textStyle, .blockStyle, .lists, .link, .history])
```

An empty array hides the keyboard toolbar.

## Add Colors and Custom Buttons

``RichTextToolbarConfiguration`` controls everything the toolbar shows. Custom actions receive the editor's ``RichTextContext``, so they can read state and run any command:

```swift
let configuration = RichTextToolbarConfiguration(
    sections: [.textStyle, .lists, .colorPalette],
    colors: [
        RichTextColor("Ink", .label),
        RichTextColor("Brand", .systemIndigo),
    ],
    customActions: [
        RichTextToolbarAction(
            title: "Quote",
            systemImage: "text.quote",
            isActive: { $0.blockStyle == .quote },
            action: { $0.toggleBlockStyle(.quote) }
        ),
    ]
)

RichTextEditor(text: $text, toolbar: configuration)
```

Color names are used as VoiceOver labels.

## Place the Toolbar Yourself

On iPad, or anywhere the keyboard isn't the right home, pass `nil` for the keyboard toolbar and show ``RichTextToolbar`` with the same context:

```swift
@StateObject private var context = RichTextContext()

var body: some View {
    VStack(spacing: 0) {
        ScrollView {
            RichTextEditor(text: $text, context: context, toolbar: nil)
                .padding()
        }
        RichTextToolbar(
            context: context,
            configuration: RichTextToolbarConfiguration(showsDismissKeyboardButton: false)
        )
    }
}
```
