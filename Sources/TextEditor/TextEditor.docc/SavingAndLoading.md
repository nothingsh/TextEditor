# Saving and Loading

Store drafts losslessly and exchange content as Markdown or HTML.

## Choose a Format

``RichTextSerializer`` supports three formats. Use the archive for anything you'll load back into the editor, and Markdown or HTML to share content with other systems.

| Format   | Keeps                                                    | Drops                               |
|----------|----------------------------------------------------------|-------------------------------------|
| Archive  | Everything                                               | Nothing                             |
| HTML     | Blocks, nested lists, checkboxes, inline styles, links, colors, alignment, images | Font sizes |
| Markdown | Blocks, nested lists, task items, bold, italic, strikethrough, code, links, images | Underline, colors, sizes, alignment |

Images are embedded as base64 `data:` URIs in HTML and Markdown, so exported documents are self-contained. On import, only `data:` URI images are loaded: remote images are never fetched, so Markdown keeps them as a link and HTML drops them.

## Save a Draft

```swift
let data = try RichTextSerializer.archivedData(from: text)
try data.write(to: draftURL, options: .atomic)

text = try RichTextSerializer.attributedString(archivedData: Data(contentsOf: draftURL))
```

Saving on every keystroke is wasteful; debounce writes, for example with a short `Task.sleep` that's cancelled by the next edit.

## Exchange Markdown and HTML

```swift
let markdown = RichTextSerializer.markdown(from: text)
let html = RichTextSerializer.html(from: text)

text = RichTextSerializer.attributedString(markdown: markdown)
text = RichTextSerializer.attributedString(html: html)
```

The HTML output is a fragment without `<html>` or `<body>`, ready to embed. The HTML reader is forgiving: unclosed tags, unknown tags and entities are fine, and `<script>`, `<style>` and `<head>` contents are dropped.

The serializers assume the editor's body font and `.label` text color. If you import with a different `textColor`, pass the same color when exporting HTML, so plain text isn't written with an explicit color:

```swift
text = RichTextSerializer.attributedString(html: html, textColor: .black)
let exported = RichTextSerializer.html(from: text, textColor: .black)
```

## Link Safety

Only `http`, `https`, `mailto`, `tel` and relative links are kept. Links with other schemes, such as `javascript:`, are removed when importing Markdown or HTML, rejected by ``RichTextContext/setLink(_:)`` and the link editor, and removed again on export, so exported HTML can't carry script through link targets.

Rich text pasted from other apps is rebuilt the same way as imported HTML, so unsafe links are removed. Text copied within the editor, and attributed strings you assign to the binding, keep their links as they are until they're exported. The archive format stores them unchanged.
