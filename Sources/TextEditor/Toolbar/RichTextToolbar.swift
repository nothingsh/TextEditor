//
//  RichTextToolbar.swift
//
//

import SwiftUI

/// The formatting toolbar. All state comes from `RichTextContext`, so it always matches the selection.
///
/// `RichTextEditor` shows it above the keyboard. To place it elsewhere, such as the bottom of an iPad screen,
/// pass `toolbar: nil` to the editor and add this view yourself with the same context.
public struct RichTextToolbar: View {
    @ObservedObject private var context: RichTextContext
    private let configuration: RichTextToolbarConfiguration

    @State private var isShowingColorPalette = false

    private let barHeight: CGFloat = 44
    private let paletteHeight: CGFloat = 40

    public init(context: RichTextContext, configuration: RichTextToolbarConfiguration = .default) {
        self.context = context
        self.configuration = configuration
    }

    public var body: some View {
        VStack(spacing: 0) {
            if isShowingColorPalette && configuration.sections.contains(.colorPalette) {
                colorPalette
                Divider()
            }
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(configuration.sections, id: \.self) { section in
                            items(for: section)
                        }
                        ForEach(configuration.customActions) { action in
                            ToolbarButton(action.title, systemImage: action.systemImage, isActive: action.isActive(context)) {
                                action.action(context)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                if configuration.showsDismissKeyboardButton {
                    Divider()
                        .frame(height: 24)
                    ToolbarButton("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
                        context.dismissKeyboard()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: barHeight)
        }
    }

    @ViewBuilder
    private func items(for section: EditorSection) -> some View {
        switch section {
        case .textStyle:
            ForEach(TextStyle.allCases, id: \.self) { style in
                ToolbarButton(style.title, systemImage: style.systemImage, isActive: context.isActive(style)) {
                    context.toggle(style)
                }
            }
        case .blockStyle:
            blockStyleMenu
        case .lists:
            ForEach([BlockStyle.bulletList, .numberedList], id: \.self) { style in
                ToolbarButton(style.title, systemImage: style.systemImage, isActive: context.blockStyle == style) {
                    context.toggleBlockStyle(style)
                }
            }
        case .fontAdjustment:
            ToolbarButton("Decrease Font Size", systemImage: "minus.circle") {
                context.adjustFontSize(by: -1)
            }
            .disabled(!context.canDecreaseFontSize)
            Text("\(Int(context.fontSize.rounded()))")
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .frame(minWidth: 26)
                .accessibilityLabel("Font size \(Int(context.fontSize.rounded()))")
            ToolbarButton("Increase Font Size", systemImage: "plus.circle") {
                context.adjustFontSize(by: 1)
            }
            .disabled(!context.canIncreaseFontSize)
        case .textAlignment:
            ToolbarButton("Alignment", systemImage: context.alignment.systemImage) {
                context.setAlignment(context.alignment.next)
            }
        case .colorPalette:
            ToolbarButton("Text Color", systemImage: "paintpalette", isActive: isShowingColorPalette) {
                isShowingColorPalette.toggle()
            }
        case .link:
            ToolbarButton(context.link == nil ? "Add Link" : "Edit Link", systemImage: "link", isActive: context.link != nil) {
                context.presentLinkEditor()
            }
        case .image:
            ToolbarButton("Insert Image", systemImage: "photo") {
                context.presentImagePicker()
            }
        case .history:
            ToolbarButton("Undo", systemImage: "arrow.uturn.backward") {
                context.undo()
            }
            .disabled(!context.canUndo)
            ToolbarButton("Redo", systemImage: "arrow.uturn.forward") {
                context.redo()
            }
            .disabled(!context.canRedo)
        }
    }

    private var blockStyleMenu: some View {
        let styles: [BlockStyle] = [.paragraph, .heading1, .heading2, .heading3, .quote, .codeBlock]
        let isActive = context.blockStyle != .paragraph && !context.blockStyle.isList
        return Menu {
            ForEach(styles, id: \.self) { style in
                Button {
                    context.setBlockStyle(style)
                } label: {
                    if context.blockStyle == style {
                        Label(style.title, systemImage: "checkmark")
                    } else {
                        Text(style.title)
                    }
                }
            }
        } label: {
            ToolbarIcon(systemImage: "textformat", isActive: isActive)
        }
        .accessibilityLabel("Paragraph Style")
        .accessibilityValue(context.blockStyle.title)
    }

    private var colorPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(configuration.colors, id: \.self) { entry in
                    let isSelected = entry.color.isEqual(context.textColor)
                    Button {
                        context.setTextColor(entry.color)
                    } label: {
                        Circle()
                            .fill(Color(uiColor: entry.color))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(uiColor: .systemBackground))
                                }
                            }
                    }
                    .accessibilityLabel(entry.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: paletteHeight)
    }
}

struct ToolbarButton: View {
    private let title: String
    private let systemImage: String
    private let isActive: Bool
    private let action: () -> Void

    init(_ title: String, systemImage: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ToolbarIcon(systemImage: systemImage, isActive: isActive)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct ToolbarIcon: View {
    let systemImage: String
    let isActive: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17))
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color(uiColor: .tertiarySystemFill) : .clear)
            )
    }
}

private extension TextStyle {
    var title: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .underline: return "Underline"
        case .strikethrough: return "Strikethrough"
        case .code: return "Code"
        }
    }

    var systemImage: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

private extension BlockStyle {
    var title: String {
        switch self {
        case .paragraph: return "Body"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .bulletList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .quote: return "Quote"
        case .codeBlock: return "Code Block"
        }
    }

    var systemImage: String {
        switch self {
        case .bulletList: return "list.bullet"
        case .numberedList: return "list.number"
        default: return "textformat"
        }
    }
}

private extension NSTextAlignment {
    var systemImage: String {
        switch self {
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        case .justified: return "text.justify"
        default: return "text.alignleft"
        }
    }

    /// left → center → right → justified → left
    var next: NSTextAlignment {
        switch self {
        case .center: return .right
        case .right: return .justified
        case .justified: return .left
        default: return .center
        }
    }
}
