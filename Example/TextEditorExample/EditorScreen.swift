import SwiftUI
import TextEditor

struct EditorScreen: View {
    @ObservedObject var draft: DraftStore
    @StateObject private var context = RichTextContext()

    @State private var isShowingExport = false
    @State private var isConfirmingReset = false
    @AppStorage("markdownShortcuts") private var isMarkdownShortcutsEnabled = true

    var body: some View {
        NavigationStack {
            // The editor scrolls itself, so long notes only lay out what's on screen.
            RichTextEditor(text: $draft.text, context: context, placeholder: "Start writing…")
            .markdownShortcuts(isMarkdownShortcutsEnabled)
            .scrollsContent()
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .task {
                // Used when capturing screenshots for the README.
                if ProcessInfo.processInfo.arguments.contains("-focusEditor") {
                    context.focus()
                }
            }
            .navigationTitle("Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Export") {
                        isShowingExport = true
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("Markdown Shortcuts", isOn: $isMarkdownShortcutsEnabled)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Restore Sample", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
            }
            .confirmationDialog("Replace the draft with the sample document?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Restore Sample", role: .destructive) {
                    draft.resetToSample()
                }
            }
            .sheet(isPresented: $isShowingExport) {
                ExportView(text: draft.text)
            }
        }
    }
}
