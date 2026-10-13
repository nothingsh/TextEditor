//
//  BlockDecorationView.swift
//
//

import UIKit

/// Shows list markers, quote bars and code block backgrounds behind the text.
///
/// UITextView keeps its text layout manager's delegate for itself, so custom layout fragments are off the table.
/// Instead, `RichTextView` reads paragraph frames from TextKit 2 after layout and hands them to this view.
///
/// The view is as tall as the document, so it never draws into its own backing store. Each decoration
/// is a small reusable layer, and only decorations near `visibleRect` get one, which keeps memory flat
/// however long the document grows.
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
                setNeedsLayout()
            }
        }
    }

    /// The part of the document on screen, in this view's coordinates; `nil` renders everything.
    var visibleRect: CGRect? {
        didSet {
            if visibleRect != oldValue {
                setNeedsLayout()
            }
        }
    }

    private var backgroundLayers: [CALayer] = []
    private var bulletLayers: [CAShapeLayer] = []
    private var numberLayers: [CATextLayer] = []

    /// Layers currently shown, for tests and diagnostics.
    var renderedLayerCount: Int {
        (backgroundLayers + bulletLayers + numberLayers).filter { !$0.isHidden }.count
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderLayers()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Layer colors are resolved CGColors, so dark mode needs a re-render.
        renderLayers()
    }

    // MARK: Rendering

    private func renderLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.commit()
        }

        // A screen of margin above and below, so fast scrolling doesn't reveal missing markers.
        let region = visibleRect.map { $0.insetBy(dx: 0, dy: -$0.height) }
        var backgroundCount = 0
        var bulletCount = 0
        var numberCount = 0

        for decoration in decorations where region.map(decoration.frame.intersects) ?? true {
            switch decoration.kind {
            case .codeBackground:
                let layer = reusableLayer(at: backgroundCount, in: &backgroundLayers, make: CALayer.init)
                layer.frame = decoration.frame
                layer.cornerRadius = 6
                layer.backgroundColor = resolved(.secondarySystemFill)
                backgroundCount += 1
            case .quoteBar:
                let layer = reusableLayer(at: backgroundCount, in: &backgroundLayers, make: CALayer.init)
                layer.frame = CGRect(x: decoration.frame.minX, y: decoration.frame.minY, width: 3, height: decoration.frame.height)
                layer.cornerRadius = 1.5
                layer.backgroundColor = resolved(.tertiaryLabel)
                backgroundCount += 1
            case .bullet:
                let layer = reusableLayer(at: bulletCount, in: &bulletLayers, make: CAShapeLayer.init)
                configureBullet(layer, for: decoration)
                bulletCount += 1
            case .number(let ordinal):
                let layer = reusableLayer(at: numberCount, in: &numberLayers, make: CATextLayer.init)
                configureNumber(layer, ordinal: ordinal, for: decoration)
                numberCount += 1
            }
        }

        hideLayers(in: backgroundLayers, from: backgroundCount)
        hideLayers(in: bulletLayers, from: bulletCount)
        hideLayers(in: numberLayers, from: numberCount)
    }

    /// A filled dot, right-aligned in the indent and centred on the x-height.
    private func configureBullet(_ layer: CAShapeLayer, for decoration: Decoration) {
        let font = markerFont(for: decoration)
        let diameter = (font.pointSize * 0.3).rounded()
        let center = CGPoint(
            x: decoration.frame.minX + decoration.indent - 8 - diameter / 2,
            y: decoration.baseline - font.xHeight / 2
        )
        layer.frame = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        layer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).cgPath
        layer.fillColor = resolved(decoration.color)
    }

    /// "12." right-aligned in the indent, on the first line's baseline.
    private func configureNumber(_ layer: CATextLayer, ordinal: Int, for decoration: Decoration) {
        let font = markerFont(for: decoration)
        // Wide enough for "100."; the layer may extend left of the text, which is fine for an unclipped sublayer.
        let width: CGFloat = 60
        layer.frame = CGRect(
            x: decoration.frame.minX + decoration.indent - 6 - width,
            y: decoration.baseline - font.ascender,
            width: width,
            height: font.lineHeight
        )
        layer.string = "\(ordinal)."
        // UIFont is toll-free bridged to CTFont; creating one by name would lose the system font.
        layer.font = font
        layer.fontSize = font.pointSize
        layer.foregroundColor = resolved(decoration.color)
        layer.alignmentMode = .right
        layer.contentsScale = traitCollection.displayScale
    }

    private func markerFont(for decoration: Decoration) -> UIFont {
        decoration.font.withTrait(.traitBold, enabled: false).withTrait(.traitItalic, enabled: false)
    }

    private func resolved(_ color: UIColor) -> CGColor {
        color.resolvedColor(with: traitCollection).cgColor
    }

    private func reusableLayer<Layer: CALayer>(at index: Int, in pool: inout [Layer], make: () -> Layer) -> Layer {
        if index < pool.count {
            pool[index].isHidden = false
            return pool[index]
        }
        let layer = make()
        self.layer.addSublayer(layer)
        pool.append(layer)
        return layer
    }

    private func hideLayers(in pool: [CALayer], from index: Int) {
        for layer in pool.dropFirst(index) {
            layer.isHidden = true
        }
    }
}
