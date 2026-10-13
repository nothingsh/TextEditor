//
//  KeyboardToolbarHost.swift
//
//

import SwiftUI

/// Hosts a SwiftUI view as a text view's `inputAccessoryView`.
///
/// The keyboard sizes an accessory from its intrinsic height, so the host reports what SwiftUI measures
/// and re-reports whenever that changes, e.g. when the color palette opens. The host itself is transparent
/// so the toolbar's capsules float over the content behind them.
final class KeyboardToolbarHost: UIInputView {
    private let hostingController: UIHostingController<AnyView>

    init<Content: View>(content: Content) {
        hostingController = UIHostingController(rootView: AnyView(content))
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 60), inputViewStyle: .default)
        autoresizingMask = .flexibleHeight
        backgroundColor = .clear

        hostingController.sizingOptions = .intrinsicContentSize
        // The toolbar sets its own padding; inherited safe area insets would make it uneven.
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
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

    func update<Content: View>(content: Content) {
        hostingController.rootView = AnyView(content)
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight)
    }

    private var contentHeight: CGFloat {
        let width = bounds.width > 0 ? bounds.width : window?.bounds.width ?? UIScreen.main.bounds.width
        return hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    /// SwiftUI content changes, like the palette opening, relayout the hosted view; pass the new height on.
    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(contentHeight - bounds.height) > 0.5 {
            invalidateIntrinsicContentSize()
        }
    }
}
