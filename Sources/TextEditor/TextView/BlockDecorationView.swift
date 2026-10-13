//
//  BlockDecorationView.swift
//
//

import UIKit

/// Draws list markers, quote bars and code block backgrounds behind the text.
///
/// UITextView keeps its text layout manager's delegate for itself, so custom layout fragments are off the table.
/// Instead, `RichTextView` reads paragraph frames from TextKit 2 after layout and hands them to this view.
final class BlockDecorationView: UIView {
    struct Decoration: Equatable {
        enum Kind: Equatable {
            case bullet
            case number(Int)
            case quoteBar
            case codeBackground
        }

        var kind: Kind
        /// The paragraph's frame in text view coordinates.
        var frame: CGRect
        /// Baseline of the paragraph's first line, used to align markers.
        var baseline: CGFloat
        var indent: CGFloat
        var font: UIFont
        var color: UIColor
    }

    var decorations: [Decoration] = [] {
        didSet {
            if decorations != oldValue {
                setNeedsDisplay()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        for decoration in decorations {
            switch decoration.kind {
            case .codeBackground:
                UIColor.secondarySystemFill.setFill()
                UIBezierPath(roundedRect: decoration.frame, cornerRadius: 6).fill()
            case .quoteBar:
                UIColor.tertiaryLabel.setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: decoration.frame.minX, y: decoration.frame.minY, width: 3, height: decoration.frame.height),
                    cornerRadius: 1.5
                ).fill()
            case .bullet:
                drawMarker("•", for: decoration)
            case .number(let ordinal):
                drawMarker("\(ordinal).", for: decoration)
            }
        }
    }

    /// Right-aligns the marker in the paragraph's indent, on the first line's baseline.
    private func drawMarker(_ marker: String, for decoration: Decoration) {
        let font = decoration.font.withTrait(.traitBold, enabled: false).withTrait(.traitItalic, enabled: false)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: decoration.color]
        let size = (marker as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: decoration.frame.minX + decoration.indent - 6 - size.width,
            y: decoration.baseline - font.ascender
        )
        (marker as NSString).draw(at: origin, withAttributes: attributes)
    }
}
