//
//  EditorSection.swift
//
//
//  Created by Steven Zhang on 3/15/22.
//

/// Groups of controls shown in the toolbar, in the order given.
public enum EditorSection: CaseIterable, Hashable {
    /// bold, italic, underline, strikethrough and inline code
    case textStyle
    /// a menu of body, headings, quote and code block
    case blockStyle
    /// bulleted and numbered lists
    case lists
    /// decrease and increase font size
    case fontAdjustment
    /// cycle paragraph alignment
    case textAlignment
    /// text color palette
    case colorPalette
    /// add, edit or remove a link
    case link
    /// insert an image from the photo library
    case image
    /// undo and redo
    case history
}
