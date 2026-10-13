//
//  EditorSection.swift
//
//

/// Groups of controls shown in the toolbar, in the order given.
public enum EditorSection: CaseIterable, Hashable {
    /// Bold, italic, underline, strikethrough and inline code.
    case textStyle
    /// A menu of body, headings, quote and code block.
    case blockStyle
    /// Bulleted, numbered and checklist items, and buttons that nest and unnest them.
    case lists
    /// Decrease and increase font size.
    case fontAdjustment
    /// Cycles paragraph alignment through left, center, right and justified.
    case textAlignment
    /// Opens a palette of text colors above the toolbar.
    case colorPalette
    /// Adds, edits or removes a link.
    case link
    /// Inserts an image from the photo library.
    case image
    /// Opens the system find and replace bar.
    case find
    /// Undo and redo.
    case history
}
