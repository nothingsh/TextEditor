import SwiftUI
import TextEditor

/// Keeps the document on disk in the lossless archive format, saving shortly after each edit.
@MainActor
final class DraftStore: ObservableObject {
    @Published var text: NSAttributedString {
        didSet {
            scheduleSave()
        }
    }

    private let fileURL = URL.documentsDirectory.appending(path: "Draft.richtext")
    private var saveTask: Task<Void, Never>?

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? RichTextSerializer.attributedString(archivedData: data) {
            text = saved
        } else {
            text = RichTextSerializer.attributedString(markdown: SampleDocument.markdown)
        }
    }

    func resetToSample() {
        text = RichTextSerializer.attributedString(markdown: SampleDocument.markdown)
    }

    /// Debounced so typing doesn't write to disk on every keystroke.
    private func scheduleSave() {
        saveTask?.cancel()
        let text = text
        let fileURL = fileURL
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let data = try? RichTextSerializer.archivedData(from: text) else {
                return
            }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
