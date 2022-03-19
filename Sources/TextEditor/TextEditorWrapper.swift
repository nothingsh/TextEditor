//
//  File.swift
//  
//
//  Created by Steven Zhang on 3/12/22.
//

import SwiftUI

@available(iOS 13.0, *)
final class TextEditorWrapper: UIViewControllerRepresentable {
    private var richText: NSMutableAttributedString
    @Binding private var height: CGFloat
    
    private var controller: UIViewController
    private var textView: UITextView
    private var accessoryView: InputAccessoryView
    
    private let placeholder: String
    private let lineSpacing: CGFloat = 3
    private let hintColor = UIColor.placeholderText
    private let defaultFontSize = UIFont.systemFontSize
    private let defaultFontName = "AvenirNext-Regular"
    
    private var defaultFont: UIFont {
        return UIFont(name: defaultFontName, size: defaultFontSize) ?? .systemFont(ofSize: defaultFontSize)
    }
    
    // TODO: line width, line style
    init(richText: NSMutableAttributedString, height: Binding<CGFloat>, placeholder: String, sections: Array<EditorSection>) {
        self.richText = richText
        self._height = height
        self.controller = UIViewController()
        self.textView = UITextView()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 40)
        self.placeholder = placeholder
        
        self.accessoryView = InputAccessoryView(frame: rect, accessorySections: sections)
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        setUpTextView()
        textView.delegate = context.coordinator
        context.coordinator.textViewDidChange(textView)
        
        accessoryView.delegate = context.coordinator
        textView.inputAccessoryView = accessoryView
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setUpTextView() {
        if richText.string == "" {
            textView.attributedText = NSAttributedString(string: placeholder, attributes: [.foregroundColor: hintColor])
        } else {
            textView.attributedText = richText
        }
        textView.typingAttributes = [.font : defaultFont]
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = true
        textView.textAlignment = .left
        
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.backgroundColor = .clear
        
        controller.view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
            textView.widthAnchor.constraint(equalTo: controller.view.widthAnchor),
        ])
    }
    
    private func scaleImage(image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage {
        let ratio = image.size.width / image.size.height
        let imageW: CGFloat = (ratio >= 1) ? maxWidth : image.size.width*(maxHeight/image.size.height)
        let imageH: CGFloat = (ratio <= 1) ? maxHeight : image.size.height*(maxWidth/image.size.width)
        UIGraphicsBeginImageContext(CGSize(width: imageW, height: imageH))
        image.draw(in: CGRect(x: 0, y: 0, width: imageW, height: imageH))
        let scaledimage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledimage!
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TextEditorDelegate {
        var parent: TextEditorWrapper
        var fontName: String
        
        private var isBold = false
        private var isItalic = false
        
        init(_ parent: TextEditorWrapper) {
            self.parent = parent
            self.fontName = parent.defaultFontName
        }
        
        // MARK: - Image Picker
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[UIImagePickerController.InfoKey.editedImage] as? UIImage, var image = img.roundedImageWithBorder(color: .opaqueSeparator) {
                textViewDidBeginEditing(parent.textView)
                let newString = NSMutableAttributedString(attributedString: parent.textView.attributedText)
                image = scaleImage(image: image, maxWidth: 180, maxHeight: 180)
                
                let textAttachment = NSTextAttachment(image: image)
                let attachmentString = NSAttributedString(attachment: textAttachment)
                newString.append(attachmentString)
                parent.textView.attributedText = newString
                textViewDidChange(parent.textView)
            }
            picker.dismiss(animated: true, completion: nil)
        }
        
        func scaleImage(image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage {
            let ratio = image.size.width / image.size.height
            let imageW: CGFloat = (ratio >= 1) ? maxWidth : image.size.width*(maxHeight/image.size.height)
            let imageH: CGFloat = (ratio <= 1) ? maxHeight : image.size.height*(maxWidth/image.size.width)
            UIGraphicsBeginImageContext(CGSize(width: imageW, height: imageH))
            image.draw(in: CGRect(x: 0, y: 0, width: imageW, height: imageH))
            let scaledimage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return scaledimage!
        }
        
        // MARK: - Text Editor
        
        /// - If user doesn't selecte any text, make follow typing text bold
        /// - if user selected text contain bold, then make them plain, else make them bold
        func textBold(fontSize: CGFloat) -> Bool {
            let defaultFont = UIFont.systemFont(ofSize: fontSize)
            isBold = textEffect(type: UIFont.self, key: .font, value: UIFont.boldSystemFont(ofSize: fontSize), defaultValue: defaultFont)
            return isBold
        }
        
        func textUnderline() -> Bool {
            textEffect(type: Int.self, key: .underlineStyle, value: NSUnderlineStyle.single.rawValue, defaultValue: .zero)
        }
        
        func textItalic(fontSize: CGFloat) -> Bool {
            let defaultFont = UIFont.systemFont(ofSize: fontSize)
            isItalic = textEffect(type: UIFont.self, key: .font, value: UIFont.italicSystemFont(ofSize: fontSize), defaultValue: defaultFont)
            return isItalic
        }
        
        func textStrike() -> Bool {
            textEffect(type: Int.self, key: .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, defaultValue: .zero)
        }
        
        func textAlign(align: NSTextAlignment) {
            parent.textView.textAlignment = align
        }
        
        func adjustFontSize(fontSize: CGFloat) {
            let defaultFont = UIFont.systemFont(ofSize: fontSize)
            var font: UIFont
            
            if isBold {
                font = UIFont.boldSystemFont(ofSize: fontSize)
            } else if isItalic {
                font = UIFont.italicSystemFont(ofSize: fontSize)
            } else {
                font = defaultFont
            }
            
            textEffect(type: UIFont.self, key: .font, value: font, defaultValue: defaultFont)
        }
        
        func textFont(name: String, fontSize: CGFloat) {
            fontName = name
            let defaultFont = UIFont.systemFont(ofSize: fontSize)
            let newFont = UIFont(name: fontName, size: fontSize) ?? defaultFont
            textEffect(type: UIFont.self, key: .font, value: newFont, defaultValue: defaultFont)
        }
        
        func textColor(color: UIColor) {
            textEffect(type: UIColor.self, key: .foregroundColor, value: color, defaultValue: color)
        }
        
        func insertImage() {
            let sourceType = UIImagePickerController.SourceType.photoLibrary
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = sourceType
            parent.controller.present(imagePicker, animated: true, completion: nil)
        }
        
        func insertLine(name: String) {
            if let line = UIImage(named: name) {
                let newString = NSMutableAttributedString(attributedString: parent.textView.attributedText)
                let image = scaleImage(image: line, maxWidth: 280, maxHeight: 20)
                let attachment = NSTextAttachment(image: image)
                let attachedString = NSAttributedString(attachment: attachment)
                newString.append(attachedString)
                parent.textView.attributedText = newString
            }
        }
        
        func hideKeyboard() {
            parent.textView.resignFirstResponder()
        }
        
        /// Add text attributes to text view
        /// - Returns:If text view's typing attributes revised, return true; if attributes are only for text in selected range, return false.
        @discardableResult private func textEffect<T: Equatable>(type: T.Type, key: NSAttributedString.Key, value: Any, defaultValue: T) -> Bool {
            let range = parent.textView.selectedRange
            if !range.isEmpty {
                let isContain = isContain(type: type, range: range, key: key, value: value)
                let mutableString = NSMutableAttributedString(attributedString: parent.textView.attributedText)
                if isContain {
                    mutableString.removeAttribute(key, range: range)
                } else {
                    mutableString.addAttributes([key : value], range: range)
                    // Make following text be standard
                    parent.textView.typingAttributes.removeValue(forKey: key)
                }
                parent.textView.attributedText = mutableString
            } else {
                if let current = parent.textView.typingAttributes[key], current as! T == value as! T {
                    parent.textView.typingAttributes[key] = defaultValue
                } else {
                    parent.textView.typingAttributes[key] = value
                    return true
                }
            }
            return false
        }
        
        /// Find specific attribute in the range of text which user selected
        /// - parameter range: Selected range in text view
        private func isContain<T: Equatable>(type: T.Type, range: NSRange, key: NSAttributedString.Key, value: Any) -> Bool {
            var isContain: Bool = false
            parent.textView.attributedText.enumerateAttributes(in: range) { attributes, range, stop in
                if attributes.filter({ $0.key == key }).contains(where: {
                    $0.value as! T == value as! T
                }) {
                    isContain = true
                    stop.pointee = true
                }
            }
            return isContain
        }
        
        
        // MARK: - Text View Delegate
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.attributedText.string == parent.placeholder {
                textView.attributedText = NSAttributedString(string: "")
                textView.typingAttributes[.foregroundColor] = UIColor.black
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.attributedText.string == "" {
                textView.attributedText = NSAttributedString(string: parent.placeholder)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if textView.attributedText.string != parent.placeholder {
                parent.richText = NSMutableAttributedString(attributedString: textView.attributedText)
            }
            let size = CGSize(width: parent.controller.view.frame.width, height: .infinity)
            let estimatedSize = textView.sizeThatFits(size)
            if parent.height != estimatedSize.height {
                DispatchQueue.main.async {
                    self.parent.height = estimatedSize.height
                }
            }
            textView.scrollRangeToVisible(textView.selectedRange)
        }
    }
}
