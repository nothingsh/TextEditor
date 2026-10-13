//
//  UIKit+RichText.swift
//
//

import UIKit

extension UIFont {
    func hasTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        fontDescriptor.symbolicTraits.contains(trait)
    }

    /// Returns a font of the same family and size with `trait` added or removed,
    /// so bold and italic can be combined and the family is never swapped for the system font.
    /// Falls back to `self` when the family has no such variant.
    func withTrait(_ trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if enabled {
            traits.insert(trait)
        } else {
            traits.remove(trait)
        }
        guard traits != fontDescriptor.symbolicTraits,
              let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 0xff,
            green: CGFloat((hex >> 8) & 0xff) / 0xff,
            blue: CGFloat(hex & 0xff) / 0xff,
            alpha: alpha
        )
    }
}

extension UIImage {
    /// Downsamples the image to at most `maxWidth` points wide. The renderer draws at screen scale,
    /// which keeps the result sharp on Retina displays without holding full-resolution photos in memory.
    func scaledToFit(width maxWidth: CGFloat) -> UIImage {
        guard size.width > maxWidth, size.width > 0 else {
            return self
        }
        let targetSize = CGSize(width: maxWidth, height: (size.height * maxWidth / size.width).rounded())
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
