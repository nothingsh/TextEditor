import SwiftUI

@available(iOS 13.0, *)
public struct RichTextEditor: View {
    @State var dynamicHeight: CGFloat = 100
    
    private let richText: NSMutableAttributedString
    private let placeholder: String
    private let accessorySections: Array<EditorSection>
    
    public init(richText: NSMutableAttributedString, placeholder: String = "Type ...", accessory sections: Array<EditorSection> = EditorSection.all) {
        self.richText = richText
        self.placeholder = placeholder
        self.accessorySections = sections
    }
    
    public var body: some View {
        TextEditorWrapper(richText: richText, height: $dynamicHeight, placeholder: placeholder, sections: accessorySections)
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
        
        var body: some View {
            ZStack {
                Color(hex: "EED6C4")
                    .edgesIgnoringSafeArea(.all)
                RichTextEditor(richText: richText)
                    .padding()
                    .background(
                        Rectangle().stroke(lineWidth: 1)
                    )
                    .padding()
            }
        }
    }
}
