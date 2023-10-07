//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import SwiftUI

@available(iOS 13.0, *)
final class InputAccessoryView: UIInputView {
    private var accessorySections: Array<EditorSection>
    private var textFontName: String = "AvenirNext-Regular"
    
    private let padding: CGFloat = 5
    private let cornerRadius: CGFloat = 4
    private let selectedColor = UIColor.separator
    private let containerBackgroundColor: UIColor = .systemBackground
    private let colorConf = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    
    weak var delegate: TextEditorDelegate!
    
    // MARK: Input Accessory
    
    /// buttons include bold, italic, underline, strike through effects
    private lazy var textStyleStack: UIStackView = {
        var systemNames = ["bold", "italic", "underline", "strikethrough"]
        
        let buttons = systemNames.enumerated().map { (index, systemName) in
            let button = ActionButton(systemName: systemName)
            button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
            button.tag = index + 1
            return button
        }

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.distribution = .fillEqually
        stackView.backgroundColor = .clear
        stackView.spacing = padding
        stackView.alignment = .center
        return stackView
    }()
    
    /// increase and decrease font size button, and font size label
    private lazy var fontSizeAdjustmentStack: UIStackView = {
        let size: CGFloat = 24
        let textFontSizeLabel = UILabel()
        textFontSizeLabel.textAlignment = .center
        textFontSizeLabel.font = UIFont.systemFont(ofSize: size * 0.8)
        textFontSizeLabel.text = "\(Int(UIFont.systemFontSize))"
        textFontSizeLabel.textColor = .systemBlue
        textFontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        textFontSizeLabel.widthAnchor.constraint(equalToConstant: size * 1.1).isActive = true
        
        let increaseFontSizeButton = ActionButton(systemName: "minus.circle", ratio: 0.95)
        increaseFontSizeButton.addTarget(self, action: #selector(decreaseFontSize), for: .touchUpInside)
        let decreaseFontSizeButton = ActionButton(systemName: "plus.circle", ratio: 0.95)
        decreaseFontSizeButton.addTarget(self, action: #selector(increaseFontSize), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [increaseFontSizeButton, textFontSizeLabel, decreaseFontSizeButton])
        stackView.distribution = .fillEqually
        stackView.backgroundColor = .clear
        stackView.spacing = padding
        stackView.alignment = .center
        return stackView
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
        button.addTarget(self, action: #selector(showFontPalette(_:)), for: .touchUpInside)
        return button
    }()
    
    /// action button bar
    private var toolbar: UIStackView {
        let stackView = UIStackView()
        
        if accessorySections.contains(.textStyle) {
            stackView.addArrangedSubview(textStyleStack)
        }
        if accessorySections.contains(.fontAdjustment) {
            stackView.addArrangedSubview(fontSizeAdjustmentStack)
        }
        if accessorySections.contains(.textAlignment) {
            stackView.addArrangedSubview(alignmentButton)
        }
        if accessorySections.contains(.image) {
            stackView.addArrangedSubview(insertImageButton)
        }
        
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(keyboardButton)
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = padding
        stackView.distribution = .fill
        
        return stackView
    }
    
    /// color palette bar
    private lazy var colorPaletteBar: UIStackView = {
        let colorButtons = ColorLibrary.textColors.map { color in
            let button = UIButton()
            let colorConf = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.setImage(UIImage(systemName: "circle.fill", withConfiguration: colorConf), for: .normal)
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
    
    // MARK: - Initialization
    
    private var accessoryContentView: UIStackView
    
    init(inputViewStyle: UIInputView.Style, accessorySections: Array<EditorSection>) {
        self.accessoryContentView = UIStackView()
        self.accessorySections = accessorySections
        super.init(frame: .zero, inputViewStyle: inputViewStyle)
        
        self.setupAccessoryView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAccessoryView() {
        accessoryContentView.addArrangedSubview(toolbar)
        if accessorySections.contains(.colorPalette) {
            accessoryContentView.addArrangedSubview(colorPaletteBar)
        }
        
        accessoryContentView.axis = .vertical
        accessoryContentView.alignment = .leading
        accessoryContentView.distribution = .fillProportionally
        
        addSubview(accessoryContentView)
        backgroundColor = .secondarySystemBackground
        accessoryContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            accessoryContentView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 1.5*padding),
            accessoryContentView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -1.5*padding),
            accessoryContentView.topAnchor.constraint(equalTo: self.topAnchor),
            accessoryContentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    var isDisplayColorPalette: Bool {
        return self.accessorySections.contains(.colorPalette)
    }
    
    // MARK: - Actions
    
    @objc private func showFontPalette(_ button: UIButton) {
        //
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
    
    /// update toolbar buttons and colors based on current typing attributes
    func updateToolbar(typingAttributes: [NSAttributedString.Key : Any], textAlignment: NSTextAlignment) {
        self.alignmentButton.setImage(systemName: textAlignment.imageName)
        
        for attribute in typingAttributes {
            if attribute.key == .font {
                let boldButton = self.textStyleStack.arrangedSubviews[0] as! UIButton
                let italicButton = self.textStyleStack.arrangedSubviews[1] as! UIButton
                
                if let font = attribute.value as? UIFont {
                    let fontSize = font.pointSize
                    
                    (self.fontSizeAdjustmentStack.arrangedSubviews[1] as! UILabel).text = "\(Int(fontSize))"
                    let isBold = (font == UIFont.boldSystemFont(ofSize: fontSize))
                    let isItalic = (font == UIFont.italicSystemFont(ofSize: fontSize))
                    self.selectedButton(boldButton, isSelected: isBold)
                    self.selectedButton(italicButton, isSelected: isItalic)
                } else {
                    self.selectedButton(boldButton, isSelected: false)
                    self.selectedButton(italicButton, isSelected: false)
                }
            }
            
            if attribute.key == .underlineStyle {
                let underlineButton = self.textStyleStack.arrangedSubviews[2] as! UIButton
                if let style = attribute.value as? Int {
                    self.selectedButton(underlineButton, isSelected: style == NSUnderlineStyle.single.rawValue )
                } else {
                    self.selectedButton(underlineButton, isSelected: false)
                }
            }
            
            if attribute.key == .strikethroughStyle {
                let strikeButton = self.textStyleStack.arrangedSubviews[3] as! UIButton
                if let style = attribute.value as? Int {
                    self.selectedButton(strikeButton, isSelected: style == NSUnderlineStyle.single.rawValue)
                }  else {
                    self.selectedButton(strikeButton, isSelected: false)
                }
            }
            
            if attribute.key == .foregroundColor {
                var textColor = ColorLibrary.textColors.first!
                if let color = attribute.value as? UIColor {
                    textColor = color
                }
                for item in self.colorPaletteBar.arrangedSubviews {
                    let button = item as! UIButton
                    if button.tintColor == textColor {
                        button.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: colorConf), for: .normal)
                    } else {
                        button.setImage(UIImage(systemName: "circle.fill", withConfiguration: colorConf), for: .normal)
                    }
                }
            }
        }
    }
}
