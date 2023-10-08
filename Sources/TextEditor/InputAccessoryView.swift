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
    
    private let edgePadding: CGFloat = 5
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
        let size: CGFloat = 27
        let textFontSizeLabel = UILabel()
        textFontSizeLabel.textAlignment = .center
        textFontSizeLabel.font = UIFont.systemFont(ofSize: size * 0.8, weight: .light)
        textFontSizeLabel.text = "\(Int(UIFont.systemFontSize))"
        textFontSizeLabel.textColor = .systemBlue
        textFontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        textFontSizeLabel.widthAnchor.constraint(equalToConstant: size * 1.1).isActive = true
        
        let decreaseFontSizeButton = ActionButton(systemName: "minus.circle")
        decreaseFontSizeButton.addTarget(self, action: #selector(decreaseFontSize), for: .touchUpInside)
        let increaseFontSizeButton = ActionButton(systemName: "plus.circle")
        increaseFontSizeButton.addTarget(self, action: #selector(increaseFontSize), for: .touchUpInside)
        
        return [decreaseFontSizeButton, textFontSizeLabel, increaseFontSizeButton]
    }()
    
    var textAlignment: NSTextAlignment = .left {
        didSet {
            alignmentButton.setImage(systemName: self.textAlignment.imageName)
        }
    }
    
    private lazy var alignmentButton: ActionButton = {
        let button = ActionButton(systemName: NSTextAlignment.left.imageName)
        button.addTarget(self, action: #selector(alignText(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var insertImageButton: ActionButton = {
        let button = ActionButton(systemName: "photo.on.rectangle.angled")
        button.addTarget(self, action: #selector(insertImage(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var fontSelectionButton: ActionButton = {
        let button = ActionButton(systemName: "textformat.size")
        button.addTarget(self, action: #selector(toggleFontPalette(_:)), for: .touchUpInside)
        return button
    }()
    
    private let colorSelectionSymbol = "pencil.tip"
    private lazy var colorSelectionButon: ActionButton = {
        var symbolName: String = self.colorSelectionSymbol
        if #available(iOS 14, *) {
            symbolName = "paintpalette"
        }
        let button = ActionButton(systemName: symbolName)
        if symbolName == self.colorSelectionSymbol {
            button.tintColor = ColorLibrary.textColors.first!
        }
        button.addTarget(self, action: #selector(toggleColorPalette(_:)), for: .touchUpInside)
        return button
    }()
    
    // Color Palette Bar
    private let colorPaletteBarHeight: CGFloat = 33
    private lazy var colorPaletteBar: UIStackView = {
        let colorButtons = ColorLibrary.textColors.map { color in
            let button = ActionButton(systemName: "circle.fill", size: 24)
            button.tintColor = color
            button.addTarget(self, action: #selector(selectTextColor(_:)), for: .touchUpInside)
            return button
        }
        
        let containerView = UIStackView(arrangedSubviews: colorButtons)
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.spacing = edgePadding / 2
        containerView.backgroundColor = .clear
        containerView.sizeToFit()
        
        return containerView
    }()
    
    // TODO: Support Fonts Selection
    
    private lazy var fontPaletteBar: UIStackView = {
        let containerView = UIStackView()
        return containerView
    }()
    
    // MARK: Initialization
    
    var toolbarItems: [UIView] = []
    var toolbarStack: UIView!
    
    init(accessorySections: Array<EditorSection>) {
        self.accessorySections = accessorySections
        super.init(frame: .zero)
        
        self.setupAccessoryView()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAccessoryView() {
        self.axis = .vertical
        self.alignment = .leading
        self.distribution = .fillProportionally
        self.backgroundColor = .secondarySystemBackground
        self.setupToolBar()
    }
    
    private let toolbarHeight: CGFloat = 44
    private func setupToolBar() {
        self.toolbarStack = UIView()
        
        self.configureItems()
        self.addArrangedSubview(self.toolbarStack)
        self.toolbarStack.backgroundColor = .clear
        self.toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.toolbarStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.toolbarStack.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
        
        let scrollableBar = ScrollableToolbar(items: self.toolbarItems)
        scrollableBar.backgroundColor = .clear
        let keyboardEscape = UIButton()
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .light)
        let keyboardSymbolName = "keyboard.chevron.compact.down"
        keyboardEscape.layer.borderWidth = 1
        keyboardEscape.layer.cornerRadius = 5
        keyboardEscape.layer.borderColor = UIColor.systemBlue.cgColor
        keyboardEscape.addTarget(self, action: #selector(hideKeyboard), for: .touchUpInside)
        keyboardEscape.setImage(UIImage(systemName: keyboardSymbolName, withConfiguration: symbolConfiguration), for: .normal)
        
        self.toolbarStack.addSubview(scrollableBar)
        scrollableBar.translatesAutoresizingMaskIntoConstraints = false
        self.toolbarStack.addSubview(keyboardEscape)
        keyboardEscape.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollableBar.leadingAnchor.constraint(equalTo: self.toolbarStack.leadingAnchor),
            scrollableBar.trailingAnchor.constraint(equalTo: keyboardEscape.leadingAnchor),
            scrollableBar.topAnchor.constraint(equalTo: self.toolbarStack.topAnchor),
            scrollableBar.bottomAnchor.constraint(equalTo: self.toolbarStack.bottomAnchor),
            scrollableBar.heightAnchor.constraint(equalTo: self.toolbarStack.heightAnchor),
            
            keyboardEscape.trailingAnchor.constraint(equalTo: self.toolbarStack.trailingAnchor),
            keyboardEscape.centerYAnchor.constraint(equalTo: self.toolbarStack.centerYAnchor),
            keyboardEscape.heightAnchor.constraint(equalTo: self.toolbarStack.heightAnchor),
            keyboardEscape.widthAnchor.constraint(equalTo: keyboardEscape.heightAnchor)
        ])
    }
    
    private func configureItems() {
        if accessorySections.contains(.textStyle) {
            self.toolbarItems += textStyleItems
        }
        if accessorySections.contains(.fontAdjustment) {
            self.toolbarItems += fontSizeAdjustmentItems
        }
        if accessorySections.contains(.textAlignment) {
            self.toolbarItems.append(alignmentButton)
        }
        if accessorySections.contains(.image) {
            self.toolbarItems.append(insertImageButton)
        }
        if accessorySections.contains(.colorPalette) {
            self.toolbarItems.append(colorSelectionButon)
        }
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
        let constraint = self.constraints[2]
        constraint.constant = !hasAdditionalBar ? self.toolbarHeight + self.colorPaletteBarHeight : self.toolbarHeight
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
        if self.colorSelectionButon.symbolName == self.colorSelectionSymbol {
            self.colorSelectionButon.tintColor = currentTextColor
        }
        
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
