//
//  KeyboardToolbarHost.swift
//
//

import SwiftUI

/// Hosts a SwiftUI view as a text view's `inputAccessoryView`.
/// `allowsSelfSizing` lets the bar change height, e.g. when the color palette opens.
final class KeyboardToolbarHost: UIInputView {
    private let hostingController: UIHostingController<AnyView>

    init<Content: View>(content: Content) {
        hostingController = UIHostingController(rootView: AnyView(content))
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44), inputViewStyle: .keyboard)
        allowsSelfSizing = true

        hostingController.sizingOptions = .intrinsicContentSize
        let hostedView: UIView = hostingController.view
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
