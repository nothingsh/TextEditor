//
//  ScrollableToolbar.swift
//  
//
//  Created by Wynn Zhang on 10/8/23.
//

import UIKit

class ScrollableToolbar: UIScrollView {
    var itemStackView: UIStackView
    
    init(items: [UIView]) {
        self.itemStackView = UIStackView(arrangedSubviews: items)
        super.init(frame: .zero)
        
        self.itemStackView.axis = .horizontal
        self.itemStackView.alignment = .center
        self.itemStackView.distribution = .equalSpacing
        self.itemStackView.backgroundColor = .clear
        self.itemStackView.spacing = 4
        self.setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupToolbar() {
        self.addSubview(self.itemStackView)
        self.itemStackView.translatesAutoresizingMaskIntoConstraints = false
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.isScrollEnabled = true
        
        NSLayoutConstraint.activate([
            self.itemStackView.leadingAnchor.constraint(equalTo: self.contentLayoutGuide.leadingAnchor, constant: 8),
            self.itemStackView.trailingAnchor.constraint(equalTo: self.contentLayoutGuide.trailingAnchor),
            self.itemStackView.topAnchor.constraint(equalTo: self.contentLayoutGuide.topAnchor),
            self.itemStackView.bottomAnchor.constraint(equalTo: self.contentLayoutGuide.bottomAnchor),
            self.itemStackView.heightAnchor.constraint(equalTo: self.frameLayoutGuide.heightAnchor),
        ])
    }
}
