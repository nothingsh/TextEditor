//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import UIKit

@available(iOS 13.0, *)
final class InputAccessoryView: UIInputView {
    private var accessorySections: Array<EditorSection>
    private var textFontName: String = "AvenirNext-Regular"
    
    private let baseHeight: CGFloat = 44
    private let padding: CGFloat = 8
    private let buttonWidth: CGFloat = 32
    private let buttonHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 6
    private let edgeInsets: CGFloat = 5
    private let selectedColor = UIColor.separator
    private let containerBackgroundColor: UIColor = .systemBackground
    private let colorConf = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    private var imageConf: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: min(buttonWidth, buttonHeight) * 0.7)
    }
    
    weak var delegate: TextEditorDelegate!
    
    // MARK: Input Accessory Buttons
    
    private lazy var stackViewSeparator: UIView = {
        let separator = UIView()
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.backgroundColor = .secondaryLabel
        return separator
    }()
    
    private lazy var separator: UIView = {
        let separator = UIView()
        let spacerWidthConstraint = separator.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerWidthConstraint.priority = .defaultLow
        spacerWidthConstraint.isActive = true
        return separator
    }()
    
    private lazy var keyboardButton: UIButton = {
        let button = UIButton()
        // let keyboardButtonConf = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "keyboard.chevron.compact.down", withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(hideKeyboard(_:)), for: .touchUpInside)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 5
        button.widthAnchor.constraint(equalToConstant: buttonWidth*1.5).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var increaseFontButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus.circle", withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(increaseFontSize), for: .touchUpInside)
        button.backgroundColor = .clear
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var decreaseFontButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "minus.circle", withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(decreaseFontSize), for: .touchUpInside)
        button.backgroundColor = .clear
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var textFontLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = "\(Int(UIFont.systemFontSize))"
        
        return label
    }()
    
    private lazy var boldButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
        button.setImage(UIImage(systemName: "bold", withConfiguration: imageConf), for: .normal)
        button.backgroundColor = .clear
        button.tag = 1
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var italicButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
        button.setImage(UIImage(systemName: "italic", withConfiguration: imageConf), for: .normal)
        button.backgroundColor = .clear
        button.tag = 2
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var underlineButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
        button.setImage(UIImage(systemName: "underline", withConfiguration: imageConf), for: .normal)
        button.backgroundColor = .clear
        button.tag = 3
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var strikeButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
        button.setImage(UIImage(systemName: "strikethrough", withConfiguration: imageConf), for: .normal)
        button.backgroundColor = .clear
        button.tag = 4
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    var textAlignment: NSTextAlignment = .left {
        didSet {
            alignmentButton.setImage(UIImage(systemName: self.textAlignment.imageName, withConfiguration: imageConf), for: .normal)
        }
    }
    
    private lazy var alignmentButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: NSTextAlignment.left.imageName, withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(alignText(_:)), for: .touchUpInside)
        button.backgroundColor = .clear
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var insertImageButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(insertImage(_:)), for: .touchUpInside)
        button.backgroundColor = .clear
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    private lazy var fontSelectionButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "textformat.size", withConfiguration: imageConf), for: .normal)
        button.addTarget(self, action: #selector(showFontPalette(_:)), for: .touchUpInside)
        button.backgroundColor = .clear
        button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    // MARK: Addtional Bars
    
    private let textColors: [UIColor] = [
        UIColor.label,
        UIColor(hex: "DD4E48"),
        UIColor(hex: "ED734A"),
        UIColor(hex: "F1AA3E"),
        UIColor(hex: "479D60"),
        UIColor(hex: "5AC2C5"),
        UIColor(hex: "50AAF8"),
        UIColor(hex: "2355F6"),
        UIColor(hex: "9123F4"),
        UIColor(hex: "EA5CAE")
    ]
    
    private lazy var colorButtons: [UIButton] = {
        var buttons: [UIButton] = []
        
        for color in textColors {
            let button = UIButton()
            button.setImage(UIImage(systemName: "circle.fill", withConfiguration: colorConf), for: .normal)
            button.tintColor = color
            button.addTarget(self, action: #selector(selectColor(_:)), for: .touchUpInside)
            buttons.append(button)
        }
        
        return buttons
    }()
    
    private lazy var colorPaletteBar: UIStackView = {
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
    
    init(frame: CGRect, inputViewStyle: UIInputView.Style, accessorySections: Array<EditorSection>) {
        self.accessoryContentView = UIStackView()
        self.accessorySections = accessorySections
        super.init(frame: frame, inputViewStyle: inputViewStyle)
        
        setupAccessoryView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAccessoryView() {
        accessoryContentView.addArrangedSubview(toolbar)
        if accessorySections.contains(.color) {
            accessoryContentView.addArrangedSubview(colorPaletteBar)
        }
        
        accessoryContentView.axis = .vertical
        accessoryContentView.alignment = .leading
        accessoryContentView.distribution = .fillProportionally
        
        addSubview(accessoryContentView)
        backgroundColor = .secondarySystemBackground
        accessoryContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            accessoryContentView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: padding),
            accessoryContentView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -padding),
            accessoryContentView.topAnchor.constraint(equalTo: self.topAnchor),
            accessoryContentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    private var toolbar: UIStackView {
        let stackView = UIStackView()
        
        if accessorySections.contains(.bold) {
            stackView.addArrangedSubview(boldButton)
        }
        if accessorySections.contains(.italic) {
            stackView.addArrangedSubview(italicButton)
        }
        if accessorySections.contains(.underline) {
            stackView.addArrangedSubview(underlineButton)
        }
        if accessorySections.contains(.strike) {
            stackView.addArrangedSubview(strikeButton)
        }
        
        if accessorySections.contains(.textAlignment) {
            stackView.addArrangedSubview(alignmentButton)
        }
        if accessorySections.contains(.fontAdjustment) {
            stackView.addArrangedSubview(decreaseFontButton)
            stackView.addArrangedSubview(textFontLabel)
            stackView.addArrangedSubview(increaseFontButton)
        }
        if accessorySections.contains(.image) {
            stackView.addArrangedSubview(insertImageButton)
        }
        
        stackView.addArrangedSubview(separator)
        if accessorySections.contains(.keyboard) {
            stackView.addArrangedSubview(keyboardButton)
        }
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = padding
        stackView.distribution = .equalSpacing
        
        return stackView
    }
    
    // MARK: - Button Actions
    
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
    
    @objc private func selectColor(_ button: UIButton) {
        delegate.textColor(color: button.tintColor)
    }
    
    private func selectedButton(_ button: UIButton, isSelected: Bool) {
        button.layer.cornerRadius = isSelected ? cornerRadius : 0
        button.layer.backgroundColor = isSelected ? selectedColor.cgColor : UIColor.clear.cgColor
    }
    
    func updateToolbar(typingAttributes: [NSAttributedString.Key : Any], textAlignment: NSTextAlignment) {
        alignmentButton.setImage(UIImage(systemName: textAlignment.imageName, withConfiguration: imageConf), for: .normal)
        
        for attribute in typingAttributes {
            if attribute.key == .font {
                if let font = attribute.value as? UIFont {
                    let fontSize = font.pointSize
                    
                    textFontLabel.text = "\(Int(fontSize))"
                    let isBold = (font == UIFont.boldSystemFont(ofSize: fontSize))
                    let isItalic = (font == UIFont.italicSystemFont(ofSize: fontSize))
                    selectedButton(boldButton, isSelected: isBold)
                    selectedButton(italicButton, isSelected: isItalic)
                } else {
                    selectedButton(boldButton, isSelected: false)
                    selectedButton(italicButton, isSelected: false)
                }
            }
            
            if attribute.key == .underlineStyle {
                if let style = attribute.value as? Int {
                    selectedButton(underlineButton, isSelected: style == NSUnderlineStyle.single.rawValue )
                } else {
                    selectedButton(underlineButton, isSelected: false)
                }
            }
            
            if attribute.key == .strikethroughStyle {
                if let style = attribute.value as? Int {
                    selectedButton(strikeButton, isSelected: style == NSUnderlineStyle.single.rawValue)
                }  else {
                    selectedButton(strikeButton, isSelected: false)
                }
            }
            
            if attribute.key == .foregroundColor {
                var textColor = textColors.first!
                if let color = attribute.value as? UIColor {
                    textColor = color
                }
                for button in colorButtons {
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
