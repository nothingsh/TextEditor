//
//  ActionButton.swift
//  
//
//  Created by Wynn Zhang on 10/7/23.
//

import UIKit

class ActionButton: UIButton {
    private let size: CGFloat = 30
    private var pointSizeRatio: CGFloat
    
    init(systemName: String, ratio: CGFloat? = nil) {
        self.pointSizeRatio = 0.8 * (ratio != nil ? ratio! : 1)
        super.init(frame: CGRect(origin: .zero, size: .zero))
        
        self.setImage(UIImage(systemName: systemName, withConfiguration: symbolConfiguration), for: .normal)
        self.backgroundColor = .clear
        if ratio == nil {
            self.widthAnchor.constraint(equalToConstant: self.size).isActive = true
            self.heightAnchor.constraint(equalToConstant: self.size).isActive = true
        }
    }
    
    func setImage(systemName: String) {
        self.setImage(UIImage(systemName: systemName, withConfiguration: symbolConfiguration), for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var symbolConfiguration: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: self.size * self.pointSizeRatio)
    }
}
