//
//  RichTextToolbarConfiguration.swift
//
//

import UIKit

/// What the formatting toolbar shows.
public struct RichTextToolbarConfiguration {
    /// Built-in sections, in display order.
    public var sections: [EditorSection]
    /// Colors offered by the `.colorPalette` section.
    public var colors: [RichTextColor]
    /// Your own buttons, shown after the built-in sections.
    public var customActions: [RichTextToolbarAction]
    /// Whether a hide-keyboard button is pinned to the trailing edge.
    public var showsDismissKeyboardButton: Bool
    /// Whether scrolling rows fade out at an edge that has more controls beyond it, hinting that they scroll.
    /// Rows that fit never fade.
    public var showsScrollEdgeFade: Bool

    /// Every parameter defaults to the editor's standard toolbar.
    public init(
        sections: [EditorSection] = EditorSection.allCases,
        colors: [RichTextColor] = RichTextColor.defaultPalette,
        customActions: [RichTextToolbarAction] = [],
        showsDismissKeyboardButton: Bool = true,
        showsScrollEdgeFade: Bool = true
    ) {
        self.sections = sections
        self.colors = colors
        self.customActions = customActions
        self.showsDismissKeyboardButton = showsDismissKeyboardButton
        self.showsScrollEdgeFade = showsScrollEdgeFade
    }

    /// Every section, the default palette, no custom actions, and both the hide-keyboard button and edge fade.
    public static let `default` = RichTextToolbarConfiguration()

    /// Whether the toolbar would look the same. Custom actions are compared by title and icon,
    /// since closures can't be compared.
    func isEquivalent(to other: RichTextToolbarConfiguration) -> Bool {
        sections == other.sections
            && colors == other.colors
            && showsDismissKeyboardButton == other.showsDismissKeyboardButton
            && showsScrollEdgeFade == other.showsScrollEdgeFade
            && customActions.map(\.title) == other.customActions.map(\.title)
            && customActions.map(\.systemImage) == other.customActions.map(\.systemImage)
    }
}

/// A named color offered by the toolbar's color palette.
public struct RichTextColor: Hashable {
    /// Used as the VoiceOver label.
    public var name: String
    /// The text color applied when the swatch is tapped. Dynamic colors such as `.label` adapt to dark mode.
    public var color: UIColor

    /// - Parameters:
    ///   - name: Used as the VoiceOver label.
    ///   - color: The text color applied when the swatch is tapped.
    public init(_ name: String, _ color: UIColor) {
        self.name = name
        self.color = color
    }

    /// The default text color followed by nine hues, from red to pink.
    public static let defaultPalette: [RichTextColor] = [
        RichTextColor("Default", .label),
        RichTextColor("Red", UIColor(hex: 0xDD4E48)),
        RichTextColor("Orange", UIColor(hex: 0xED734A)),
        RichTextColor("Yellow", UIColor(hex: 0xF1AA3E)),
        RichTextColor("Green", UIColor(hex: 0x479D60)),
        RichTextColor("Teal", UIColor(hex: 0x5AC2C5)),
        RichTextColor("Sky", UIColor(hex: 0x50AAF8)),
        RichTextColor("Blue", UIColor(hex: 0x2355F6)),
        RichTextColor("Purple", UIColor(hex: 0x9123F4)),
        RichTextColor("Pink", UIColor(hex: 0xEA5CAE)),
    ]
}

/// A custom toolbar button. The closures receive the editor's context, so actions can read state and run commands.
///
/// Actions are identified by their title: the editor rebuilds the toolbar when titles or icons change,
/// not when only a closure does.
public struct RichTextToolbarAction: Identifiable {
    public var id: String { title }
    /// Used as the VoiceOver label, and as the action's identity, so titles must be unique.
    public var title: String
    /// An SF Symbols name for the button's icon.
    public var systemImage: String
    /// Whether the button is shown highlighted, read whenever the formatting at the selection changes.
    public var isActive: @MainActor (RichTextContext) -> Bool
    /// Runs when the button is tapped.
    public var action: @MainActor (RichTextContext) -> Void

    /// - Parameters:
    ///   - title: Used as the VoiceOver label, and as the action's identity, so titles must be unique.
    ///   - systemImage: An SF Symbols name for the button's icon.
    ///   - isActive: Whether the button is shown highlighted. Never highlighted by default.
    ///   - action: Runs when the button is tapped.
    public init(
        title: String,
        systemImage: String,
        isActive: @escaping @MainActor (RichTextContext) -> Bool = { _ in false },
        action: @escaping @MainActor (RichTextContext) -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }
}
