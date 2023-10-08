//
//  ActionButton.swift
//  
//
//  Created by Wynn Zhang on 10/7/23.
//

import UIKit

class ActionButton: UIButton {
    private static let SYMBOL_SIZE: CGFloat = 32
    private let size: CGFloat
    var symbolName: String
    
    init(systemName: String, size: CGFloat = ActionButton.SYMBOL_SIZE) {
        self.size = size
        self.symbolName = systemName
        super.init(frame: CGRect(origin: .zero, size: .zero))
        
        self.backgroundColor = .clear
        self.setImage(systemName: systemName)
    }
    
    func setImage(systemName: String) {
        guard let image = UIImage(systemName: systemName, withConfiguration: symbolConfiguration) else {
            return
        }
        
        guard image.size.height != 0 else {
            return
        }
        
        self.setImage(image, for: .normal)
        
        let ratio = image.size.width / image.size.height
        let aspectRatio = (ratio > 1.1) ? ratio : 1
        let adjustedWidth = self.size * aspectRatio
        self.widthAnchor.constraint(equalToConstant: adjustedWidth).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.size).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var symbolConfiguration: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: size * 0.85, weight: .light, scale: .small)
    }
}
