//
//  RichTextView+KeyCommands.swift
//
//

import UIKit

/// Hardware keyboard shortcuts, listed in the ⌘ overlay on iPad. ⌘B, ⌘I and ⌘U come from UIKit's edit actions,
/// and ⌘F, ⌘G and ⌥⌘F from the find interaction.
enum EditorKeyCommand: String, CaseIterable {
    case strikethrough, code, link
    case body, heading1, heading2, heading3, bulletList, numberedList, checklist, quote, codeBlock
    case indent, outdent, toggleChecked
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
        case .checklist: return "Checklist"
        case .indent: return "Indent"
        case .outdent: return "Outdent"
        case .toggleChecked: return "Mark as Checked"
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
        case .checklist: return "l"
        case .indent: return "]"
        case .outdent: return "["
        case .toggleChecked: return "u"
        case .quote: return "'"
        case .codeBlock: return "c"
        case .increaseFontSize: return "="
        case .decreaseFontSize: return "-"
        }
    }

    var modifierFlags: UIKeyModifierFlags {
        switch self {
        case .strikethrough, .bulletList, .numberedList, .checklist, .toggleChecked: return [.command, .shift]
        case .body, .heading1, .heading2, .heading3, .codeBlock: return [.command, .alternate]
        case .code, .link, .quote, .indent, .outdent, .increaseFontSize, .decreaseFontSize: return .command
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
        case .checklist: return .checklist
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
        // In a list item, Tab and Shift-Tab nest and unnest it. Elsewhere, and while composing with an
        // input method, Tab keeps its usual meaning. They have no title, so they stay out of the ⌘ overlay.
        guard markedTextRange == nil, currentBlockStyle.isList else {
            return (super.keyCommands ?? []) + commands
        }
        let tab = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(indentListItemsFromKeyboard))
        let shiftTab = UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(outdentListItemsFromKeyboard))
        for command in [tab, shiftTab] {
            command.wantsPriorityOverSystemBehavior = true
        }
        return (super.keyCommands ?? []) + commands + [tab, shiftTab]
    }

    @objc private func indentListItemsFromKeyboard() {
        indentListItems()
    }

    @objc private func outdentListItemsFromKeyboard() {
        outdentListItems()
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
        case .indent: indentListItems()
        case .outdent: outdentListItems()
        case .toggleChecked: toggleChecklistItems()
        case .increaseFontSize: adjustFontSize(by: 1)
        case .decreaseFontSize: adjustFontSize(by: -1)
        default: break
        }
    }
}
