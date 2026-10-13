//
//  MarkdownSerialization.swift
//
//

import UIKit

/// Writes CommonMark with GitHub-style strikethrough.
/// Underline, color, font size and alignment have no Markdown syntax and are dropped.
enum MarkdownWriter {
    typealias Paragraph = RichTextDocument.Paragraph
    typealias Segment = RichTextDocument.Segment

    static func markdown(from paragraphs: [Paragraph]) -> String {
        let ordinals = RichTextDocument.ordinals(of: paragraphs)
        var output = ""
        var previousBlock: BlockStyle?
        var index = 0
        /// The content indent of each open list level, which nested items are indented by.
        var listIndents: [Int] = []

        func append(_ block: String, style: BlockStyle) {
            if !style.isList {
                listIndents = []
            }
            if !output.isEmpty {
                switch (previousBlock, style) {
                case let (previous?, current) where previous.isList && current.isList:
                    output += "\n"
                case (.quote, .quote):
                    // Keeps consecutive quote paragraphs in one block quote without merging their lines.
                    output += "\n>\n"
                default:
                    output += "\n\n"
                }
            }
            output += block
            previousBlock = style
        }

        while index < paragraphs.count {
            let paragraph = paragraphs[index]

            if paragraph.block == .codeBlock {
                var lines: [String] = []
                while index < paragraphs.count, paragraphs[index].block == .codeBlock {
                    lines.append(paragraphs[index].segments.map(\.text).joined())
                    index += 1
                }
                let fence = codeFence(for: lines)
                append(fence + "\n" + lines.joined(separator: "\n") + "\n" + fence, style: .codeBlock)
                continue
            }

            let content = inlineMarkdown(paragraph.segments, isHeading: paragraph.block.isHeading)
            switch paragraph.block {
            case .heading1, .heading2, .heading3:
                append(String(repeating: "#", count: paragraph.block.headingLevel ?? 1) + " " + content, style: paragraph.block)
            case .bulletList, .numberedList, .checklist:
                // A nested item can't skip levels.
                let level = min(paragraph.level, listIndents.count)
                listIndents.removeLast(listIndents.count - level)
                let indent = String(repeating: " ", count: listIndents.reduce(0, +))
                let marker: String
                switch paragraph.block {
                case .numberedList: marker = "\(ordinals[index]). "
                case .checklist: marker = paragraph.isChecked ? "- [x] " : "- [ ] "
                default: marker = "- "
                }
                // A task's checkbox is part of its content, so nested items align with the text after "- ".
                listIndents.append(paragraph.block == .numberedList ? marker.count : 2)
                append(indent + marker + content, style: paragraph.block)
            case .quote:
                append("> " + escapingLineStart(content), style: .quote)
            case .paragraph, .codeBlock:
                if content.isEmpty {
                    // Markdown can't represent empty paragraphs; still let them end a list.
                    previousBlock = .paragraph
                    listIndents = []
                } else {
                    append(escapingLineStart(content), style: .paragraph)
                }
            }
            index += 1
        }
        return output
    }

    // MARK: Inline

    static func inlineMarkdown(_ segments: [Segment], isHeading: Bool) -> String {
        mergedIgnoringColor(segments).map { segment in
            if let image = segment.image {
                return "![](\(ImageAttachments.dataURI(for: image)))"
            }
            var styles = segment.styles
            if isHeading {
                // Headings are bold by definition.
                styles.remove(.bold)
            }
            let text = segment.text.replacingOccurrences(of: "\u{2028}", with: " ")
            // Emphasis markers can't sit next to whitespace, so keep it outside them.
            let core = text.trimmingCharacters(in: .whitespaces)
            guard !core.isEmpty else {
                return text
            }
            let leading = String(text.prefix(while: { $0 == " " || $0 == "\t" }))
            let trailing = String(text.reversed().prefix(while: { $0 == " " || $0 == "\t" }).reversed())

            var body = styles.contains(.code) ? codeSpan(core) : escaped(core)
            if styles.contains(.strikethrough) {
                body = "~~\(body)~~"
            }
            if styles.contains(.italic) {
                body = "*\(body)*"
            }
            if styles.contains(.bold) {
                body = "**\(body)**"
            }
            if let link = segment.link {
                let destination = link.absoluteString
                    .replacingOccurrences(of: "(", with: "%28")
                    .replacingOccurrences(of: ")", with: "%29")
                    .replacingOccurrences(of: " ", with: "%20")
                body = "[\(body)](\(destination))"
            }
            return leading + body + trailing
        }
        .joined()
    }

    /// Color isn't written, so segments that differ only by color would otherwise produce `**a****b**`.
    private static func mergedIgnoringColor(_ segments: [Segment]) -> [Segment] {
        var merged: [Segment] = []
        for segment in segments {
            if let last = merged.last, last.image == nil, segment.image == nil,
               last.styles == segment.styles, last.link == segment.link {
                merged[merged.count - 1].text += segment.text
            } else {
                merged.append(segment)
            }
        }
        return merged
    }

    private static let escapedCharacters: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", ">", "~", "&", "|"]

    static func escaped(_ text: String) -> String {
        var result = ""
        for character in text {
            if escapedCharacters.contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }

    /// Escapes text that would otherwise start a heading, list or quote.
    private static func escapingLineStart(_ line: String) -> String {
        if let first = line.first, "#-+=".contains(first) {
            return "\\" + line
        }
        let digits = line.prefix(while: \.isNumber)
        if !digits.isEmpty, let marker = line.dropFirst(digits.count).first, marker == "." || marker == ")" {
            return digits + "\\" + line.dropFirst(digits.count)
        }
        return line
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }

    private static func codeSpan(_ code: String) -> String {
        let fence = String(repeating: "`", count: longestBacktickRun(in: code) + 1)
        let padding = code.hasPrefix("`") || code.hasSuffix("`") ? " " : ""
        return fence + padding + code + padding + fence
    }

    private static func codeFence(for lines: [String]) -> String {
        String(repeating: "`", count: max(3, lines.map(longestBacktickRun(in:)).max() ?? 0) + 1)
    }
}

/// Reads Markdown with Foundation's CommonMark parser and maps its presentation intents onto block styles.
enum MarkdownReader {
    typealias Paragraph = RichTextDocument.Paragraph
    typealias Segment = RichTextDocument.Segment

    static func paragraphs(from markdown: String) -> [Paragraph] {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown.components(separatedBy: .newlines).map {
                Paragraph(block: .paragraph, alignment: .natural, segments: [Segment(text: $0)])
            }
        }

        var paragraphs: [Paragraph] = []
        var currentIdentity: Int?

        for run in parsed.runs {
            let identity = run.presentationIntent?.components.first?.identity
            let block = blockStyle(for: run.presentationIntent)
            let text = String(parsed[run.range].characters)

            if block == .codeBlock {
                // A code block arrives as one string; each line becomes its own code paragraph.
                var lines = text.components(separatedBy: "\n")
                if lines.count > 1, lines.last == "" {
                    lines.removeLast()
                }
                for (offset, line) in lines.enumerated() {
                    if offset == 0, identity == currentIdentity, !paragraphs.isEmpty {
                        paragraphs[paragraphs.count - 1].segments.append(Segment(text: line))
                    } else {
                        paragraphs.append(Paragraph(block: .codeBlock, alignment: .natural, segments: [Segment(text: line)]))
                    }
                }
                currentIdentity = identity
                continue
            }

            if identity != currentIdentity || paragraphs.isEmpty {
                paragraphs.append(Paragraph(block: block, alignment: .natural, segments: [], level: listLevel(for: run.presentationIntent)))
                currentIdentity = identity
            }
            paragraphs[paragraphs.count - 1].segments.append(segment(text: text, run: run))
        }
        return paragraphs.map(readingTaskMarker)
    }

    /// Nesting depth of the innermost list, from 0.
    private static func listLevel(for intent: PresentationIntent?) -> Int {
        let lists = intent?.components.filter {
            switch $0.kind {
            case .orderedList, .unorderedList: return true
            default: return false
            }
        }
        return max(0, (lists?.count ?? 0) - 1)
    }

    /// GitHub task list items arrive as list items starting with a literal `[ ] ` or `[x] `.
    private static func readingTaskMarker(_ paragraph: Paragraph) -> Paragraph {
        guard paragraph.block.isList, var first = paragraph.segments.first, first.image == nil, first.link == nil else {
            return paragraph
        }
        let isChecked: Bool
        if first.text.hasPrefix("[ ] ") {
            isChecked = false
        } else if first.text.hasPrefix("[x] ") || first.text.hasPrefix("[X] ") {
            isChecked = true
        } else {
            return paragraph
        }
        first.text.removeFirst(4)
        var result = paragraph
        result.block = .checklist
        result.isChecked = isChecked
        result.segments = (first.text.isEmpty ? [] : [first]) + paragraph.segments.dropFirst()
        return result
    }

    private static func segment(text: String, run: AttributedString.Runs.Run) -> Segment {
        if let imageURL = run.imageURL {
            if let image = ImageAttachments.payload(fromDataURI: imageURL.absoluteString) {
                return Segment(text: "", image: image)
            }
            // Remote images can't be fetched here; keep the alt text, linked to the image.
            let link = RichTextDocument.isSafeLink(imageURL) ? imageURL : nil
            return Segment(text: text.isEmpty ? imageURL.absoluteString : text, link: link)
        }
        var styles: Set<TextStyle> = []
        if let intent = run.inlinePresentationIntent {
            if intent.contains(.stronglyEmphasized) { styles.insert(.bold) }
            if intent.contains(.emphasized) { styles.insert(.italic) }
            if intent.contains(.strikethrough) { styles.insert(.strikethrough) }
            if intent.contains(.code) { styles.insert(.code) }
        }
        // Hard line breaks stay inside the paragraph.
        let text = text.replacingOccurrences(of: "\n", with: "\u{2028}")
        let link = run.link.flatMap { RichTextDocument.isSafeLink($0) ? $0 : nil }
        return Segment(text: text, styles: styles, link: link)
    }

    private static func blockStyle(for intent: PresentationIntent?) -> BlockStyle {
        guard let components = intent?.components else {
            return .paragraph
        }
        for component in components {
            switch component.kind {
            case .header(let level):
                return BlockStyle(headingLevel: level)
            case .codeBlock:
                return .codeBlock
            default:
                continue
            }
        }
        // Components run innermost first, so the nearest list wins.
        for component in components {
            switch component.kind {
            case .orderedList:
                return .numberedList
            case .unorderedList:
                return .bulletList
            default:
                continue
            }
        }
        if components.contains(where: { if case .blockQuote = $0.kind { return true } else { return false } }) {
            return .quote
        }
        return .paragraph
    }
}
