//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/15/22.
//

import SwiftUI

public enum EditorSection {
    case textStyle
    case fontAdjustment
    case textAlignment
    case media
    
    public static let all: Array<EditorSection> = [.textStyle, .fontAdjustment, .textAlignment, .media]
}
