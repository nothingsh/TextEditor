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

    /// Debounced so typing doesn't write to disk on every keystroke, and archived off the main thread.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = Snapshot(text: text)
        let fileURL = fileURL
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else {
                return
            }
            await Task.detached(priority: .utility) {
                guard let data = try? RichTextSerializer.archivedData(from: snapshot.text) else {
                    return
                }
                try? data.write(to: fileURL, options: .atomic)
            }.value
        }
    }
}

/// The editor hands out a fresh immutable snapshot on every edit, so reading it on another thread is safe.
private struct Snapshot: @unchecked Sendable {
    let text: NSAttributedString
}
