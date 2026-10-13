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

    public init(
        sections: [EditorSection] = EditorSection.allCases,
        colors: [RichTextColor] = RichTextColor.defaultPalette,
        customActions: [RichTextToolbarAction] = [],
        showsDismissKeyboardButton: Bool = true
    ) {
        self.sections = sections
        self.colors = colors
        self.customActions = customActions
        self.showsDismissKeyboardButton = showsDismissKeyboardButton
    }

    public static let `default` = RichTextToolbarConfiguration()
}

public struct RichTextColor: Hashable {
    /// Used as the VoiceOver label.
    public var name: String
    public var color: UIColor

    public init(_ name: String, _ color: UIColor) {
        self.name = name
        self.color = color
    }

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
public struct RichTextToolbarAction: Identifiable {
    public var id: String { title }
    public var title: String
    public var systemImage: String
    public var isActive: @MainActor (RichTextContext) -> Bool
    public var action: @MainActor (RichTextContext) -> Void

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
