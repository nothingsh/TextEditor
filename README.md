# TextEditor
<img src="https://img.shields.io/badge/PLATFORM-IOS%20-lightgray?style=for-the-badge" />&nbsp;&nbsp;&nbsp;<img src="https://img.shields.io/badge/LICENSE-MIT-lightgray?style=for-the-badge" />&nbsp;&nbsp;&nbsp;<img src="https://img.shields.io/badge/MADE WITH-UIKIT-orange?style=for-the-badge" />


## Preview

```swift
import TextEditor

struct ContentView: View {
    let richText = NSMutableAttributedString()
    
    var body: some View {
        ZStack {
            Color(hex: "97DBAE")
                .edgesIgnoringSafeArea(.all)
            RichTextEditor(richText: richText) { _ in
                // try to save edited rich text here
            }
            .padding(10)
            .background(
                Rectangle()
                    .stroke(lineWidth: 1)
            )
            .padding()
        }
    }
}
```

<img src="toolbar.png" alt="Preview Image" width="250"/>


## Usage

Add the following lines to your `Package.swift` or use Xcode "Add Package Dependency" menu.

```swift
.package(name: "TextEditor", url: "https://github.com/nothingsh/TextEditor", ...)
```

## Todo

- [ ] Add font selection
- [ ] Make Input Accessory View Configurable 
