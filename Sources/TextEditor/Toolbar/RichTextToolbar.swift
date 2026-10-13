//
//  RichTextToolbar.swift
//
//

import SwiftUI

/// The formatting toolbar: a floating capsule of controls, with the color palette in its own capsule above it.
/// On iOS 26 both use Liquid Glass; earlier versions use a translucent material.
///
/// All state comes from `RichTextContext`, so the toolbar always matches the selection.
/// `RichTextEditor` shows it above the keyboard. To place it elsewhere, such as the bottom of an iPad screen,
/// pass `toolbar: nil` to the editor and add this view yourself with the same context.
public struct RichTextToolbar: View {
    @ObservedObject private var context: RichTextContext
    private let configuration: RichTextToolbarConfiguration

    @State private var isShowingColorPalette = false

    /// Rows get the same padding above and below, so controls sit in the middle of each capsule.
    private let rowPadding: CGFloat = 6
    private let capsuleSpacing: CGFloat = 8

    public init(context: RichTextContext, configuration: RichTextToolbarConfiguration = .default) {
        self.context = context
        self.configuration = configuration
    }

    public var body: some View {
        GlassGroup(spacing: capsuleSpacing) {
            VStack(spacing: capsuleSpacing) {
                if isShowingColorPalette && configuration.sections.contains(.colorPalette) {
                    colorPalette
                        .toolbarCapsule()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                controls
                    .toolbarCapsule()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, rowPadding)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isShowingColorPalette)
    }

    private var controls: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(configuration.sections, id: \.self) { section in
                        items(for: section)
                    }
                    ForEach(configuration.customActions) { action in
                        ToolbarButton(action.title, systemImage: action.systemImage, isActive: action.isActive(context)) {
                            action.action(context)
                        }
                    }
                }
                .padding(.horizontal, rowPadding)
            }
            if configuration.showsDismissKeyboardButton {
                Divider()
                    .frame(height: 24)
                ToolbarButton("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
                    context.dismissKeyboard()
                }
                .padding(.horizontal, rowPadding)
            }
        }
        .padding(.vertical, rowPadding)
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
        // Hug the swatches when they fit; scroll when there are too many.
        ViewThatFits(in: .horizontal) {
            colorSwatches
            ScrollView(.horizontal, showsIndicators: false) {
                colorSwatches
            }
        }
        .padding(.vertical, rowPadding)
    }

    private var colorSwatches: some View {
        HStack(spacing: 4) {
            ForEach(configuration.colors, id: \.self) { entry in
                let isSelected = entry.color.isEqual(context.textColor)
                Button {
                    context.setTextColor(entry.color)
                } label: {
                    Circle()
                        .fill(Color(uiColor: entry.color))
                        .frame(width: 26, height: 26)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(uiColor: .systemBackground))
                            }
                        }
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel(entry.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, rowPadding + 4)
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
                Circle()
                    .fill(isActive ? Color.primary.opacity(0.12) : .clear)
            )
    }
}

// MARK: - Capsule Styling

private extension View {
    func toolbarCapsule() -> some View {
        modifier(ToolbarCapsule())
    }
}

/// Liquid Glass on iOS 26, a material capsule before that.
private struct ToolbarCapsule: ViewModifier {
    func body(content: Content) -> some View {
        let clipped = content.clipShape(Capsule())
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            clipped.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            material(clipped)
        }
        #else
        material(clipped)
        #endif
    }

    private func material(_ content: some View) -> some View {
        content
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
}

/// Lets neighbouring glass capsules blend as they appear and disappear on iOS 26.
private struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
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
