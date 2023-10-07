//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import SwiftUI

@available(iOS 13.0, *)
public extension Color {
    init(hex: String, alpha: Double = 1) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = (rgbValue & 0xff)
        
        self.init(red: Double(r)/0xff, green: Double(g)/0xff, blue: Double(b)/0xff, opacity: alpha)
    }
}

public extension UIColor {
    convenience init(hex: String, alpha: Double = 1) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = (rgbValue & 0xff)
        
        self.init(red: Double(r)/0xff, green: Double(g)/0xff, blue: Double(b)/0xff, alpha: alpha)
    }
}

class ColorLibrary {
    static private let textColorHeses: [String] = ["DD4E48", "ED734A", "F1AA3E", "479D60", "5AC2C5", "50AAF8", "2355F6", "9123F4", "EA5CAE"]
    static let textColors: [UIColor] = [UIColor.label] + textColorHeses.map({ UIColor(hex: $0) })
}

extension UIImage {
    func roundedImageWithBorder(color: UIColor) -> UIImage? {
        let length = min(size.width, size.height)
        let borderWidth = length * 0.04
        let cornerRadius = length * 0.01
        
        let rect = CGSize(width: size.width+borderWidth*1.5, height:size.height+borderWidth*1.8)
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: rect))
        imageView.backgroundColor = color
        imageView.contentMode = .center
        imageView.image = self
        imageView.layer.cornerRadius = cornerRadius
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = borderWidth
        imageView.layer.borderColor = color.cgColor
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

extension NSRange {
    var isEmpty: Bool {
        return self.upperBound == self.lowerBound
    }
}

extension CGSize {
    /// min value of width and height
    var minLength: CGFloat {
        return min(self.width, self.height)
    }
}
