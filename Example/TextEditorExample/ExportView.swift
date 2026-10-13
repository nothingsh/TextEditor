import SwiftUI
import TextEditor

/// Shows the document as Markdown or HTML, ready to copy or share.
struct ExportView: View {
    let text: NSAttributedString

    @Environment(\.dismiss) private var dismiss
    @State private var format = Format.markdown

    enum Format: String, CaseIterable, Identifiable {
        case markdown = "Markdown"
        case html = "HTML"

        var id: Self { self }
    }

    private var output: String {
        switch format {
        case .markdown: return RichTextSerializer.markdown(from: text)
        case .html: return RichTextSerializer.html(from: text)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(output)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .safeAreaInset(edge: .top) {
                Picker("Format", selection: $format) {
                    ForEach(Format.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: output)
                }
            }
        }
    }
}
