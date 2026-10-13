//
//  RichTextView+Links.swift
//
//

import UIKit

extension RichTextView {
    /// Sets or removes the link on the selection, or on the whole link under the caret.
    /// With a bare caret outside any link, inserts the URL itself as linked text.
    /// Links with unsafe schemes such as `javascript:` are ignored.
    func setLink(_ url: URL?) {
        if let url, !RichTextDocument.isSafeLink(url) {
            return
        }
        let range = linkTargetRange
        guard range.length > 0 else {
            guard let url else {
                return
            }
            var attributes = typingAttributes
            attributes[.link] = url
            let linkText = NSAttributedString(string: url.absoluteString, attributes: attributes)
            let caret = NSRange(location: range.location + linkText.length, length: 0)
            replace(range, with: linkText, selecting: caret, actionName: "Add Link")
            // Text typed after the link shouldn't extend it.
            typingAttributes[.link] = nil
            return
        }
        editAttributes(in: range, actionName: url == nil ? "Remove Link" : "Add Link") { text, range in
            if let url {
                text.addAttribute(.link, value: url, range: range)
            } else {
                text.removeAttribute(.link, range: range)
            }
        }
    }

    /// The selection, or the full extent of the link touching the caret.
    var linkTargetRange: NSRange {
        guard selectedRange.length == 0 else {
            return selectedRange
        }
        let caret = selectedRange.location
        for location in [caret - 1, caret] where location >= 0 && location < textStorage.length {
            var effectiveRange = NSRange()
            let fullRange = NSRange(location: 0, length: textStorage.length)
            if textStorage.attribute(.link, at: location, longestEffectiveRange: &effectiveRange, in: fullRange) != nil {
                return effectiveRange
            }
        }
        return selectedRange
    }

    func presentLinkEditor() {
        guard let presenter = nearestViewController else {
            return
        }
        let existingLink = RichTextFormatter.link(in: textStorage, at: selectedRange)
        let selection = selectedRange

        let alert = UIAlertController(title: existingLink == nil ? "Add Link" : "Edit Link", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://example.com"
            field.text = existingLink?.absoluteString
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }

        let finish: (URL??) -> Void = { [weak self] change in
            guard let self else {
                return
            }
            self.becomeFirstResponder()
            self.selectedRange = selection
            if let change {
                self.setLink(change)
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in finish(nil) })
        if existingLink != nil {
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in finish(.some(nil)) })
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak alert] _ in
            let url = Self.normalizedURL(from: alert?.textFields?.first?.text ?? "")
            finish(url.map { .some($0) })
        })
        presenter.present(alert, animated: true)
    }

    /// Accepts bare domains like `example.com` by assuming https, and rejects unsafe schemes.
    static func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if let url = URL(string: trimmed), url.scheme != nil {
            return RichTextDocument.isSafeLink(url) ? url : nil
        }
        return URL(string: "https://" + trimmed)
    }
}
