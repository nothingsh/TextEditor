//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import UIKit

@available(iOS 13.0, *)
final class InputAccessoryView: UIView {
    private var accessorySections: Array<EditorSection>
    private var stackView: UIStackView
    private var toolbar: UIStackView
    
    private var textFontSize: CGFloat = UIFont.systemFontSize {
        didSet {
            if let label = adjustFontView.subviews[1] as? UILabel {
                label.text = "\(Int(textFontSize))"
            }
        }
    }
    
    private var textFontName: String = "AvenirNext-Regular"
    
    private let baseHeight: CGFloat = 44
    private let padding: CGFloat = 8
    private let buttonWidth: CGFloat = 28
    private let buttonHeight: CGFloat = 30
    private let cornerRadius: CGFloat = 6
    private let edgeInsets: CGFloat = 5
    private let selectedColor = UIColor.gray
    private let containerBackgroundColor: UIColor = .lightGray
    private let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    
    weak var delegate: TextEditorDelegate!
    
    // MARK: Configure Views
    
    private lazy var stackViewSeparator: UIView = {
        let separator = UIView()
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.backgroundColor = .secondaryLabel
        return separator
    }()
    
    private lazy var keyboardButton: UIButton = {
        let button = UIButton()
        // let keyboardButtonConf = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        button.addTarget(self, action: #selector(hideKeyboard(_:)), for: .touchUpInside)
        button.backgroundColor = .lightGray
        button.layer.cornerRadius = 5
        button.widthAnchor.constraint(equalToConstant: buttonWidth*1.5).isActive = true
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return button
    }()
    
    /// Create adjust font view
    private lazy var adjustFontView: UIView = {
        let containerView = UIView()
        
        let decreaseFontButton = UIButton(frame: CGRect(x: edgeInsets, y: 0, width: buttonWidth, height: buttonHeight))
        let fontSizeLabel = UILabel(frame: CGRect(x: buttonWidth+edgeInsets, y: 0, width: buttonWidth, height: buttonHeight))
        let increaseFontButton = UIButton(frame: CGRect(x: buttonWidth*2+edgeInsets, y: 0, width: buttonWidth, height: buttonHeight))
        increaseFontButton.addTarget(self, action: #selector(increaseFontSize), for: .touchUpInside)
        decreaseFontButton.addTarget(self, action: #selector(decreaseFontSize), for: .touchUpInside)
        increaseFontButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        decreaseFontButton.setImage(UIImage(systemName: "minus.circle"), for: .normal)
        fontSizeLabel.textAlignment = .center
        fontSizeLabel.text = "\(Int(textFontSize))"
        increaseFontButton.backgroundColor = .clear
        decreaseFontButton.backgroundColor = .clear
        
        containerView.addSubview(increaseFontButton)
        containerView.addSubview(fontSizeLabel)
        containerView.addSubview(decreaseFontButton)
        containerView.backgroundColor = containerBackgroundColor
        containerView.layer.cornerRadius = 4
        containerView.widthAnchor.constraint(equalToConstant: buttonWidth*3+edgeInsets*2).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return containerView
    }()
    
    private lazy var textAlignmentView: UIView = {
        let containerView = UIView()
        let alignments: [NSTextAlignment] = [.left, .center, .right]
        
        for index in 0..<3 {
            let button = UIButton(frame: CGRect(x: edgeInsets+buttonWidth*CGFloat(index), y: 0, width: buttonWidth, height: buttonHeight))
            button.tag = index+1
            button.addTarget(self, action: #selector(alignText(_:)), for: .touchUpInside)
            button.setImage(UIImage(systemName: alignments[index].imageName), for: .normal)
            button.backgroundColor = .clear
            containerView.addSubview(button)
        }
        
        containerView.backgroundColor = containerBackgroundColor
        containerView.layer.cornerRadius = 4
        containerView.widthAnchor.constraint(equalToConstant: buttonWidth*3+2*edgeInsets).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return containerView
    }()
    
    private lazy var textStyleView: UIView = {
        let containerView = UIView()
        let images: [String] = ["bold", "italic", "underline", "strikethrough"]
        
        for index in 0..<4 {
            let button = UIButton(frame: CGRect(x: edgeInsets+buttonWidth*CGFloat(index), y: 0, width: buttonWidth, height: buttonHeight))
            button.tag = index + 1
            button.addTarget(self, action: #selector(textStyle(_:)), for: .touchUpInside)
            button.setImage(UIImage(systemName: images[index]), for: .normal)
            button.backgroundColor = .clear
            containerView.addSubview(button)
        }
        
        containerView.backgroundColor = containerBackgroundColor
        containerView.layer.cornerRadius = 4
        containerView.widthAnchor.constraint(equalToConstant: buttonWidth*4+2*edgeInsets).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return containerView
    }()
    
    // TODO: Support Fonts Selection,
    private lazy var mediaView: UIView = {
        let containerView = UIView()
        let images = ["paintpalette", "photo.on.rectangle.angled", "textformat.size"]
        
        
        for index in 0..<2 {
            let button = UIButton(frame: CGRect(x: edgeInsets+buttonWidth*CGFloat(index), y: 0, width: buttonWidth, height: buttonHeight))
            button.setImage(UIImage(systemName: images[index]), for: .normal)
            button.backgroundColor = .clear
            if index == 0 {
                button.addTarget(self, action: #selector(showColorPalette), for: .touchUpInside)
            } else if index == 1 {
                button.addTarget(self, action: #selector(insertImage(_:)), for: .touchUpInside)
            } else {
                button.addTarget(self, action: #selector(showFontPalette(_:)), for: .touchUpInside)
            }
            containerView.addSubview(button)
        }
        
        containerView.backgroundColor = containerBackgroundColor
        containerView.layer.cornerRadius = 4
        containerView.widthAnchor.constraint(equalToConstant: buttonWidth*2+2*edgeInsets).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        
        return containerView
    }()
    
    // MARK: Addtional Bars
    
    private lazy var colorPaletteBar: UIStackView = {
        let containerView = UIStackView()
        let colors = ColorLibrary.textColors
        
        for color in colors {
            let button = UIButton()
            button.setImage(UIImage(systemName: "circle.fill", withConfiguration: imageConfiguration), for: .normal)
            button.tintColor = color
            button.addTarget(self, action: #selector(selectColor(_:)), for: .touchUpInside)
            containerView.addArrangedSubview(button)
        }
        
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
    
    init(frame: CGRect, accessorySections: Array<EditorSection>) {
        self.accessorySections = accessorySections
        stackView = UIStackView()
        toolbar = UIStackView()
        
        super.init(frame: frame)
        
        setUpStackView()
        setUpToolbar()
        setUpBaseView()
        
        self.backgroundColor = UIColor(hex: "D6D7E7")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpBaseView() {
        let baseView = UIView()
        let scrollView = UIScrollView()
        
        scrollView.contentSize.height = 0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        
        stackView.addArrangedSubview(baseView)
        baseView.addSubview(scrollView)
        scrollView.addSubview(toolbar)
        
        baseView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let spacing = (baseHeight-buttonHeight)/2
        
        NSLayoutConstraint.activate([
            baseView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            baseView.heightAnchor.constraint(equalToConstant: baseHeight),
            
            scrollView.widthAnchor.constraint(equalTo: baseView.widthAnchor),
            scrollView.heightAnchor.constraint(equalTo: baseView.heightAnchor),
            scrollView.centerXAnchor.constraint(equalTo: baseView.centerXAnchor),
            scrollView.centerYAnchor.constraint(equalTo: baseView.centerYAnchor),
            
            toolbar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: spacing),
            toolbar.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -spacing)
        ])
    }
    
    private func setUpStackView () {
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(stackView)
        self.autoresizingMask = .flexibleHeight
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -padding),
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    private func setUpToolbar() {
        if accessorySections.contains(.textStyle) {
            toolbar.addArrangedSubview(textStyleView)
        }
        if accessorySections.contains(.fontAdjustment) {
            toolbar.addArrangedSubview(adjustFontView)
        }
        if accessorySections.contains(.textAlignment) {
            toolbar.addArrangedSubview(textAlignmentView)
        }
        if accessorySections.contains(.media) {
            toolbar.addArrangedSubview(mediaView)
        }
        toolbar.addArrangedSubview(keyboardButton)
        
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = padding
        toolbar.distribution = .equalSpacing
    }
    
    override var intrinsicContentSize: CGSize {
        let stackSize = stackView.sizeThatFits(CGSize(width: stackView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: self.bounds.width, height: stackSize.height)
    }
    
    // MARK: - Button Actions
    
    @objc private func showColorPalette() {
        if stackView.arrangedSubviews.first != colorPaletteBar {
            if stackView.arrangedSubviews.count > 1 {
                stackView.arrangedSubviews.first?.removeFromSuperview()
            }
            stackView.insertArrangedSubview(colorPaletteBar, at: 0)
            self.invalidateIntrinsicContentSize()
        } else {
            colorPaletteBar.removeFromSuperview()
        }
    }
    
    @objc private func showFontPalette(_ button: UIButton) {
        //
    }
    
    @objc private func hideKeyboard(_ button: UIButton) {
        delegate.hideKeyboard()
    }
    
    @objc private func textStyle(_ button: UIButton) {
        var isSelected = false
        var isMutex = false
        
        if button.tag == 1 {
            isSelected = delegate.textBold(fontSize: textFontSize)
            isMutex = isSelected
        } else if button.tag == 2 {
            isSelected = delegate.textItalic(fontSize: textFontSize)
            isMutex = isSelected
        } else if button.tag == 3 {
            isSelected = delegate.textUnderline()
        } else if button.tag == 4 {
            isSelected = delegate.textStrike()
        }
        
        if isMutex {
            button.superview?.subviews.forEach({ view in
                if view.tag == 1 || view.tag == 2 {
                    view.backgroundColor = .clear
                }
            })
        }
        
        button.backgroundColor = isSelected ? selectedColor : .clear
    }
    
    @objc private func alignText(_ button: UIButton) {
        var alignment: NSTextAlignment = .left
        if button.tag == 2 {
            alignment = .center
        }
        if button.tag == 3 {
            alignment = .right
        }
        delegate.textAlign(align: alignment)
    }
    
    @objc private func increaseFontSize() {
        textFontSize += 1
        delegate.adjustFontSize(fontSize: textFontSize)
    }
    
    @objc private func decreaseFontSize() {
        textFontSize -= 1
        delegate.adjustFontSize(fontSize: textFontSize)
    }
    
    @objc private func textFont(font: String) {
        delegate.textFont(name: font, fontSize: textFontSize)
    }
    
    @objc private func insertImage(_ button: UIButton) {
        delegate.insertImage()
    }
    
    @objc private func selectColor(_ button: UIButton) {
        for clickedButton in colorPaletteBar.subviews {
            if let current = (clickedButton as? UIButton) {
                current.setImage(UIImage(systemName: "circle.fill", withConfiguration: imageConfiguration), for: .normal)
            }
        }
        
        button.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: imageConfiguration), for: .normal)
        
        delegate.textColor(color: button.tintColor)
    }
}

extension InputAccessoryView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
    }
}
