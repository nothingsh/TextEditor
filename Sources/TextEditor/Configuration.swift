//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/15/22.
//

import SwiftUI

public enum EditorSection: CaseIterable {
    /// include bold, italic, underline, strike through font effects
    case textStyle
    /// include increase and decreas font size
    case fontAdjustment
    /// text alignment
    case textAlignment
    /// insert image
    case image
    /// text color p
    case colorPalette
}
