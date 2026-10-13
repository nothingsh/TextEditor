enum SampleDocument {
    static let markdown = """
    # Welcome to TextEditor

    A **rich text editor** for SwiftUI, backed by *TextKit 2*. Select text and use the toolbar above the keyboard, or just type Markdown.

    ## Try these

    - Start a line with `#` and a space for a heading
    - Start with `-` or `1.` and a space for a list
    - Wrap words in `**`, `*`, `~~` or backticks
    - Press Return twice to leave a list
      - Press Tab to nest an item
      - Start with `[ ]` and a space for a checklist

    - [x] Install the package
    - [ ] Tap a circle to tick it off

    1. Format some text
    2. Tap **Export** to see it as Markdown or HTML
    3. Quit and relaunch: your draft is saved

    > Everything you do is undoable, including Markdown shortcuts.

    ```
    RichTextEditor(text: $text)
        .markdownShortcuts(true)
    ```

    Read more on [GitHub](https://github.com/nothingsh/TextEditor).
    """
}
