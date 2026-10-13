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
            HorizontalToolbarScrollView(fadesEdges: configuration.showsScrollEdgeFade) {
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
            HorizontalToolbarScrollView(fadesEdges: configuration.showsScrollEdgeFade) {
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

// MARK: - Scrolling

/// Which edges of a scrolling row have more content beyond them, in layout terms:
/// SwiftUI reports scroll offsets from the leading edge, so in right-to-left layouts leading is the right side.
struct ToolbarScrollOverflow: Equatable {
    var leading = false
    var trailing = false

    /// Nothing overflows until the viewport has been measured, so a row that fits never flashes a fade.
    init(offset: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) {
        guard viewportWidth > 0 else {
            return
        }
        leading = offset > 0.5
        trailing = offset + viewportWidth < contentWidth - 0.5
    }

    init() {}

    /// Whether the physical left and right edges should fade.
    func edges(in layoutDirection: LayoutDirection) -> (left: Bool, right: Bool) {
        layoutDirection == .rightToLeft ? (trailing, leading) : (leading, trailing)
    }
}

/// A horizontal scroll view that fades whichever edge has more content beyond it,
/// so a row that happens to end on a whole button still reads as scrollable.
private struct HorizontalToolbarScrollView<Content: View>: View {
    let fadesEdges: Bool
    @ViewBuilder let content: Content

    @State private var overflow = ToolbarScrollOverflow()
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        if fadesEdges {
            trackedScrollView
                .mask(fadeMask)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                content
            }
        }
    }

    /// Both paths report only the two overflow flags, so scrolling re-renders the row
    /// only when an edge starts or stops overflowing, not on every frame.
    @ViewBuilder
    private var trackedScrollView: some View {
        if #available(iOS 18.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                content
            }
            .onScrollGeometryChange(for: ToolbarScrollOverflow.self) { geometry in
                ToolbarScrollOverflow(
                    offset: geometry.contentOffset.x + geometry.contentInsets.leading,
                    contentWidth: geometry.contentSize.width,
                    viewportWidth: geometry.containerSize.width
                )
            } action: { _, newValue in
                overflow = newValue
            }
        } else {
            LegacyTrackedScrollView(overflow: $overflow, content: content)
        }
    }

    /// Built in physical left-to-right terms: in a right-to-left layout an HStack swaps its children,
    /// but gradient start and end points don't flip, which would put each fade's clear end on the inside.
    private var fadeMask: some View {
        let edges = overflow.edges(in: layoutDirection)
        return HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(edges.left ? 0 : 1), .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: ToolbarScrollMetrics.fadeWidth)
            Rectangle()
            LinearGradient(
                colors: [.black, .black.opacity(edges.right ? 0 : 1)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: ToolbarScrollMetrics.fadeWidth)
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeOut(duration: 0.15), value: overflow)
    }
}

private enum ToolbarScrollMetrics {
    static let fadeWidth: CGFloat = 20
}

/// iOS 16 and 17 have no scroll geometry API, so the content's frame in the scroll view's own space
/// stands in for the offset. Preference keys never refresh when the toolbar is hosted as a keyboard
/// accessory; geometry changes do.
private struct LegacyTrackedScrollView<Content: View>: View {
    @Binding var overflow: ToolbarScrollOverflow
    let content: Content

    @State private var viewportWidth: CGFloat = 0
    private let coordinateSpace = "LegacyTrackedScrollView"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .onGeometryChange(for: ToolbarScrollOverflow.self) { proxy in
                    let frame = proxy.frame(in: .named(coordinateSpace))
                    return ToolbarScrollOverflow(offset: -frame.minX, contentWidth: frame.width, viewportWidth: viewportWidth)
                } action: { newValue in
                    overflow = newValue
                }
        }
        .coordinateSpace(name: coordinateSpace)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
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
