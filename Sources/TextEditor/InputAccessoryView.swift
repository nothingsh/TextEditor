//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import SwiftUI

@available(iOS 13.0, *)
final class InputAccessoryView: UIStackView {
    private var accessorySections: Array<EditorSection>
    private var textFontName: String = "AvenirNext-Regular"
    
    private let padding: CGFloat = 5
    private let cornerRadius: CGFloat = 4
    private let selectedColor = UIColor.separator
    private let containerBackgroundColor: UIColor = .systemBackground
    
    weak var delegate: TextEditorDelegate!
    
    // MARK: Input Accessory
    
    /// buttons include bold, italic, underline, strike through effects
    private lazy var textStyleItems: [UIView] = {
        var systemNames = ["bold", "italic", "underline", "strikethrough"]
        
        return systemNames.enumerated().map { (index, systemName) in
            let button = ActionButton(systemName: systemName)
            button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
            button.tag = index + 1
            return button
        }
    }()
    
    /// increase and decrease font size button, and font size label
    private lazy var fontSizeAdjustmentItems: [UIView] = {
        let size: CGFloat = 24
        let textFontSizeLabel = UILabel()
        textFontSizeLabel.textAlignment = .center
        textFontSizeLabel.font = UIFont.systemFont(ofSize: size * 0.75)
        textFontSizeLabel.text = "\(Int(UIFont.systemFontSize))"
        textFontSizeLabel.textColor = .systemBlue
        textFontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        textFontSizeLabel.widthAnchor.constraint(equalToConstant: size * 1).isActive = true
        
        let decreaseFontSizeButton = ActionButton(systemName: "minus.circle", ratio: 0.95)
        decreaseFontSizeButton.addTarget(self, action: #selector(decreaseFontSize), for: .touchUpInside)
        let increaseFontSizeButton = ActionButton(systemName: "plus.circle", ratio: 0.95)
        increaseFontSizeButton.addTarget(self, action: #selector(increaseFontSize), for: .touchUpInside)
        
        return [decreaseFontSizeButton, textFontSizeLabel, increaseFontSizeButton]
    }()
    
    // TODO: remove separator
    /// separator should be removed, and make tool bar a  horizontal scroll view in order to supporting more functionalities in the future
    private lazy var separator: UIView = {
        let separator = UIView()
        let spacerWidthConstraint = separator.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerWidthConstraint.priority = .defaultLow
        spacerWidthConstraint.isActive = true
        return separator
    }()
    
    private lazy var keyboardButton: ActionButton = {
        let button = ActionButton(systemName: "keyboard.chevron.compact.down", ratio: 0.9)
        button.addTarget(self, action: #selector(hideKeyboard(_:)), for: .touchUpInside)
        return button
    }()
    
    var textAlignment: NSTextAlignment = .left {
        didSet {
            alignmentButton.setImage(systemName: self.textAlignment.imageName)
        }
    }
    
    private lazy var alignmentButton: ActionButton = {
        let button = ActionButton(systemName: NSTextAlignment.left.imageName, ratio: 0.95)
        button.addTarget(self, action: #selector(alignText(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var insertImageButton: ActionButton = {
        let button = ActionButton(systemName: "photo.on.rectangle.angled", ratio: 0.9)
        button.addTarget(self, action: #selector(insertImage(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var fontSelectionButton: ActionButton = {
        let button = ActionButton(systemName: "textformat.size")
        button.addTarget(self, action: #selector(toggleFontPalette(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var colorSelectionButon: ActionButton = {
        let button = ActionButton(systemName: "circle")
        button.tintColor = ColorLibrary.textColors.first!
        button.addTarget(self, action: #selector(toggleColorPalette(_:)), for: .touchUpInside)
        return button
    }()
    
    // Action Button Bar
    private let toolbarHeight: CGFloat = 44
    private var toolbar: UIStackView {
        let stackView = UIStackView()
        
        if accessorySections.contains(.textStyle) {
            for item in textStyleItems {
                stackView.addArrangedSubview(item)
            }
        }
        if accessorySections.contains(.fontAdjustment) {
            for item in fontSizeAdjustmentItems {
                stackView.addArrangedSubview(item)
            }
        }
        if accessorySections.contains(.textAlignment) {
            stackView.addArrangedSubview(alignmentButton)
        }
        if accessorySections.contains(.image) {
            stackView.addArrangedSubview(insertImageButton)
        }
        if accessorySections.contains(.colorPalette) {
            stackView.addArrangedSubview(colorSelectionButon)
        }
        
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(keyboardButton)
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = padding
        stackView.distribution = .fill
        
        return stackView
    }
    
    // Color Palette Bar
    private let colorPaletteBarHeight: CGFloat = 33
    private lazy var colorPaletteBar: UIStackView = {
        let colorButtons = ColorLibrary.textColors.map { color in
            let button = ActionButton(systemName: "circle.fill", ratio: 0.8)
            button.tintColor = color
            button.addTarget(self, action: #selector(selectTextColor(_:)), for: .touchUpInside)
            return button
        }
        
        let containerView = UIStackView(arrangedSubviews: colorButtons)
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.spacing = padding/2
        
        return containerView
    }()
    
    // TODO: Support Fonts Selection
    
    private lazy var fontPaletteBar: UIStackView = {
        let containerView = UIStackView()
        return containerView
    }()
    
    // MARK: Initialization
    
    init(accessorySections: Array<EditorSection>) {
        self.accessorySections = accessorySections
        super.init(frame: .zero)
        
        self.setupAccessoryView()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAccessoryView() {
        self.addArrangedSubview(toolbar)
        
        self.axis = .vertical
        self.alignment = .leading
        self.distribution = .fillProportionally
        self.backgroundColor = .secondarySystemBackground
    }
    
    var isDisplayColorPalette: Bool {
        return self.accessorySections.contains(.colorPalette)
    }
    
    // MARK: Actions
    
    @objc private func toggleFontPalette(_ button: UIButton) {
        //
    }
    
    @objc private func toggleColorPalette(_ button: UIButton) {
        let hasAdditionalBar = self.arrangedSubviews.contains(colorPaletteBar)
        if hasAdditionalBar {
            self.colorPaletteBar.removeFromSuperview()
        } else {
            self.insertArrangedSubview(colorPaletteBar, at: 0)
        }
        // Get input accessory view's height constraint, default is equal to constant 44
        let constraint = self.constraints.first
        constraint?.constant = !hasAdditionalBar ? 77 : 44
    }
    
    @objc private func hideKeyboard(_ button: UIButton) {
        delegate.hideKeyboard()
    }
    
    @objc private func textStyle(_ button: UIButton) {
        if button.tag == 1 {
            delegate.textBold()
        } else if button.tag == 2 {
            delegate.textItalic()
        } else if button.tag == 3 {
            delegate.textUnderline()
        } else if button.tag == 4 {
            delegate.textStrike()
        }
    }
    
    @objc private func alignText(_ button: UIButton) {
        switch textAlignment {
        case .left: textAlignment = .center
        case .center: textAlignment = .right
        case .right: textAlignment = .left
        case .justified: textAlignment = .justified
        case .natural: textAlignment = .natural
        @unknown default: textAlignment = .left
        }
        delegate.textAlign(align: textAlignment)
    }
    
    @objc private func increaseFontSize() {
        delegate.adjustFontSize(isIncrease: true)
    }
    
    @objc private func decreaseFontSize() {
        delegate.adjustFontSize(isIncrease: false)
    }
    
    @objc private func textFont(font: String) {
        delegate.textFont(name: font)
    }
    
    @objc private func insertImage(_ button: UIButton) {
        delegate.insertImage()
    }
    
    @objc private func selectTextColor(_ button: UIButton) {
        delegate.textColor(color: button.tintColor)
    }
    
    /// chech if a button should be highlighted, when user clicked a button or selected text contain the effect current button corresponded to
    private func selectedButton(_ button: UIButton, isSelected: Bool) {
        button.layer.cornerRadius = isSelected ? cornerRadius : 0
        button.layer.backgroundColor = isSelected ? selectedColor.cgColor : UIColor.clear.cgColor
    }
    
    // MARK: Update Tool Bar States
    
    /// update toolbar buttons and colors based on current typing attributes
    func updateToolbar(typingAttributes: [NSAttributedString.Key : Any], textAlignment: NSTextAlignment) {
        self.alignmentButton.setImage(systemName: textAlignment.imageName)
        
        for attribute in typingAttributes {
            if attribute.key == .font {
                self.updateFontRelatedItems(attributeValue: attribute.value)
            }
            
            if attribute.key == .underlineStyle {
                self.updateTextStrikeItems(attributeValue: attribute.value, index: 2)
            }
            
            if attribute.key == .strikethroughStyle {
                self.updateTextStrikeItems(attributeValue: attribute.value, index: 3)
            }
            
            if attribute.key == .foregroundColor {
                self.updateColorPaletteItems(attributeValue: attribute.value)
            }
        }
    }
    
    /// update font size and text bold, italic effects
    private func updateFontRelatedItems(attributeValue: Any) {
        let boldButton = self.textStyleItems[0] as! UIButton
        let italicButton = self.textStyleItems[1] as! UIButton
        
        if let font = attributeValue as? UIFont {
            let fontSize = font.pointSize
            
            (self.fontSizeAdjustmentItems[1] as! UILabel).text = "\(Int(fontSize))"
            let isBold = (font == UIFont.boldSystemFont(ofSize: fontSize))
            let isItalic = (font == UIFont.italicSystemFont(ofSize: fontSize))
            self.selectedButton(boldButton, isSelected: isBold)
            self.selectedButton(italicButton, isSelected: isItalic)
        } else {
            self.selectedButton(boldButton, isSelected: false)
            self.selectedButton(italicButton, isSelected: false)
        }
    }
    
    /// update text underline and strike through effects
    private func updateTextStrikeItems(attributeValue: Any, index: Int) {
        let strikeButton = self.textStyleItems[index] as! UIButton
        if let style = attributeValue as? Int {
            self.selectedButton(strikeButton, isSelected: style == NSUnderlineStyle.single.rawValue)
        }  else {
            self.selectedButton(strikeButton, isSelected: false)
        }
    }
    
    /// update text color state
    private func updateColorPaletteItems(attributeValue: Any) {
        guard let currentTextColor = attributeValue as? UIColor else {
            return
        }
        self.colorSelectionButon.tintColor = currentTextColor
        
        guard self.contains(colorPaletteBar) else {
            return
        }
        for item in self.colorPaletteBar.arrangedSubviews {
            let button = item as! ActionButton
            if button.tintColor == currentTextColor {
                button.setImage(systemName: "checkmark.circle.fill")
            } else {
                button.setImage(systemName: "circle.fill")
            }
        }
    }
}
