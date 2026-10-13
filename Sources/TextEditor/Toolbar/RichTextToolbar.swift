//
//  RichTextToolbar.swift
//
//

import SwiftUI

/// The keyboard toolbar. All state comes from `RichTextContext`, so it always matches the selection.
struct RichTextToolbar: View {
    @ObservedObject var context: RichTextContext
    let sections: [EditorSection]

    @State private var isShowingColorPalette = false

    private let barHeight: CGFloat = 44
    private let paletteHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            if isShowingColorPalette {
                colorPalette
                Divider()
            }
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(sections, id: \.self) { section in
                            items(for: section)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                Divider()
                    .frame(height: 24)
                ToolbarButton("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
                    context.dismissKeyboard()
                }
                .padding(.horizontal, 4)
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
        case .image:
            ToolbarButton("Insert Image", systemImage: "photo") {
                context.presentImagePicker()
            }
        case .colorPalette:
            ToolbarButton("Text Color", systemImage: "paintpalette", isActive: isShowingColorPalette) {
                isShowingColorPalette.toggle()
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

    private var colorPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TextColorPalette.entries, id: \.name) { entry in
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
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color(uiColor: .tertiarySystemFill) : .clear)
                )
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

enum TextColorPalette {
    static let entries: [(name: String, color: UIColor)] = [
        ("Default", .label),
        ("Red", UIColor(hex: 0xDD4E48)),
        ("Orange", UIColor(hex: 0xED734A)),
        ("Yellow", UIColor(hex: 0xF1AA3E)),
        ("Green", UIColor(hex: 0x479D60)),
        ("Teal", UIColor(hex: 0x5AC2C5)),
        ("Sky", UIColor(hex: 0x50AAF8)),
        ("Blue", UIColor(hex: 0x2355F6)),
        ("Purple", UIColor(hex: 0x9123F4)),
        ("Pink", UIColor(hex: 0xEA5CAE)),
    ]
}

private extension TextStyle {
    var title: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .underline: return "Underline"
        case .strikethrough: return "Strikethrough"
        }
    }

    var systemImage: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
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
