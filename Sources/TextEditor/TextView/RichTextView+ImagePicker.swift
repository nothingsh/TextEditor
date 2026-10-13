//
//  RichTextView+ImagePicker.swift
//
//

import PhotosUI
import UIKit

/// `PHPickerViewController` runs out of process, so it needs no photo library permission.
extension RichTextView: PHPickerViewControllerDelegate {
    func presentImagePicker() {
        guard let presenter = nearestViewController else {
            return
        }
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else {
                return
            }
            DispatchQueue.main.async {
                self?.insertImage(image)
                self?.becomeFirstResponder()
            }
        }
    }

    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }
}
