//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import UIKit

protocol TextEditorDelegate: AnyObject {
    // Font
    func textBold(fontSize: CGFloat) -> Bool
    func textItalic(fontSize: CGFloat) -> Bool
    func textStrike() -> Bool
    func textUnderline() -> Bool
    func adjustFontSize(fontSize: CGFloat)
    func textFont(name: String, fontSize: CGFloat)
    func textColor(color: UIColor)
    func insertImage()
    func textAlign(align: NSTextAlignment)
    func hideKeyboard()
}

extension NSTextAlignment {
    var imageName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        case .justified: return "text.justify"
        case .natural: return "text.aligncenter"
        @unknown default: return "text.aligncenter"
        }
    }
    
    static let available: [NSTextAlignment] = [.left, .right, .center]
}
