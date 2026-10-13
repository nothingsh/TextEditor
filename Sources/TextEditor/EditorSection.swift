//
//  EditorSection.swift
//
//
//  Created by Steven Zhang on 3/15/22.
//

/// Groups of controls shown in the keyboard toolbar, in the order given.
public enum EditorSection: CaseIterable, Hashable {
    /// bold, italic, underline and strikethrough
    case textStyle
    /// decrease and increase font size
    case fontAdjustment
    /// cycle paragraph alignment
    case textAlignment
    /// insert an image from the photo library
    case image
    /// text color palette
    case colorPalette
    /// undo and redo
    case history
}
