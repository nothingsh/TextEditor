//
//  RichTextView+KeyCommands.swift
//
//

import UIKit

/// Hardware keyboard shortcuts, listed in the ⌘ overlay on iPad. ⌘B, ⌘I and ⌘U come from UIKit's edit actions,
/// and ⌘F, ⌘G and ⌥⌘F from the find interaction.
enum EditorKeyCommand: String, CaseIterable {
    case strikethrough, code, link
    case body, heading1, heading2, heading3, bulletList, numberedList, quote, codeBlock
    case increaseFontSize, decreaseFontSize

    var title: String {
        switch self {
        case .strikethrough: return "Strikethrough"
        case .code: return "Code"
        case .link: return "Add Link"
        case .body: return "Body"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .bulletList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .quote: return "Quote"
        case .codeBlock: return "Code Block"
        case .increaseFontSize: return "Bigger"
        case .decreaseFontSize: return "Smaller"
        }
    }

    var input: String {
        switch self {
        case .strikethrough: return "x"
        case .code: return "e"
        case .link: return "k"
        case .body: return "0"
        case .heading1: return "1"
        case .heading2: return "2"
        case .heading3: return "3"
        case .bulletList: return "8"
        case .numberedList: return "7"
        case .quote: return "'"
        case .codeBlock: return "c"
        case .increaseFontSize: return "="
        case .decreaseFontSize: return "-"
        }
    }

    var modifierFlags: UIKeyModifierFlags {
        switch self {
        case .strikethrough, .bulletList, .numberedList: return [.command, .shift]
        case .body, .heading1, .heading2, .heading3, .codeBlock: return [.command, .alternate]
        case .code, .link, .quote, .increaseFontSize, .decreaseFontSize: return .command
        }
    }

    /// The block style the command toggles, if it's a block command.
    var blockStyle: BlockStyle? {
        switch self {
        case .body: return .paragraph
        case .heading1: return .heading1
        case .heading2: return .heading2
        case .heading3: return .heading3
        case .bulletList: return .bulletList
        case .numberedList: return .numberedList
        case .quote: return .quote
        case .codeBlock: return .codeBlock
        default: return nil
        }
    }
}

extension RichTextView {
    override var keyCommands: [UIKeyCommand]? {
        guard isEditable else {
            return super.keyCommands
        }
        let commands = EditorKeyCommand.allCases.map { command in
            UIKeyCommand(
                title: command.title,
                action: #selector(performEditorKeyCommand(_:)),
                input: command.input,
                modifierFlags: command.modifierFlags,
                propertyList: command.rawValue
            )
        }
        return (super.keyCommands ?? []) + commands
    }

    @objc func performEditorKeyCommand(_ sender: UIKeyCommand) {
        guard let command = (sender.propertyList as? String).flatMap(EditorKeyCommand.init(rawValue:)) else {
            return
        }
        perform(command)
    }

    func perform(_ command: EditorKeyCommand) {
        if let block = command.blockStyle {
            block == .paragraph ? setBlockStyle(.paragraph) : toggleBlockStyle(block)
            return
        }
        switch command {
        case .strikethrough: toggle(.strikethrough)
        case .code: toggle(.code)
        case .link: presentLinkEditor()
        case .increaseFontSize: adjustFontSize(by: 1)
        case .decreaseFontSize: adjustFontSize(by: -1)
        default: break
        }
    }
}
