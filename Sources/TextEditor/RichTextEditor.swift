import SwiftUI

@available(iOS 13.0, *)
public struct RichTextEditor: View {
    @State var dynamicHeight: CGFloat = 100
    
    private let richText: NSMutableAttributedString
    private let placeholder: String
    private let accessorySections: Array<EditorSection>
    private let onCommit: (NSAttributedString) -> Void
    
    public init(
        richText: NSMutableAttributedString,
        placeholder: String = "Type ...",
        accessory sections: Array<EditorSection> = EditorSection.allCases,
        onCommit: @escaping ((NSAttributedString) -> Void)
    ) {
        self.richText = richText
        self.placeholder = placeholder
        self.accessorySections = sections
        self.onCommit = onCommit
    }
    
    public var body: some View {
        TextEditorWrapper(richText: richText, height: $dynamicHeight, placeholder: placeholder, sections: accessorySections, onCommit: onCommit)
            .frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
    }
}

@available(iOS 13.0, *)
struct RichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        Preview()
    }
    
    struct Preview: View {
        let richText: NSMutableAttributedString = NSMutableAttributedString()
        @State var text = NSAttributedString(string: "Hello")
        
        var body: some View {
            ZStack {
                Color(hex: "EED6C4")
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    RichTextEditor(richText: richText) { attributedString in
                        self.text = attributedString
                    }
                    .padding()
                    .background(
                        Rectangle().stroke(lineWidth: 1)
                    )
                    .padding()
                    Text(text.string)
                }
            }
        }
    }
}
