# Saving and Loading

Store drafts losslessly and exchange content as Markdown or HTML.

## Choose a Format

``RichTextSerializer`` supports three formats. Use the archive for anything you'll load back into the editor, and Markdown or HTML to share content with other systems.

| Format   | Keeps                                                    | Drops                               |
|----------|----------------------------------------------------------|-------------------------------------|
| Archive  | Everything                                               | Nothing                             |
| HTML     | Blocks, inline styles, links, colors, alignment, images  | Font sizes                          |
| Markdown | Blocks, bold, italic, strikethrough, code, links, images | Underline, colors, sizes, alignment |

Images are embedded as base64 `data:` URIs in HTML and Markdown, so exported documents are self-contained.

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

The HTML output is a fragment without `<html>` or `<body>`, ready to embed. The HTML reader is forgiving: unclosed tags, unknown tags and entities are fine, and `<script>` and `<style>` contents are dropped.

## Link Safety

Only `http`, `https`, `mailto`, `tel` and relative links are kept. Links with other schemes, such as `javascript:`, are removed on import and export and rejected when set in the editor, so exported HTML can't carry script through link targets.
