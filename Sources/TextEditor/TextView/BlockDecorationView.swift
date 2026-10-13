//
//  BlockDecorationView.swift
//
//

import UIKit

/// Shows list markers, checkboxes, quote bars and code block backgrounds behind the text.
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
            case bullet(level: Int)
            case number(Int)
            case checkbox(isChecked: Bool)
            case quoteBar
            case codeBackground
        }

        var kind: Kind
        /// Where the paragraph starts in the text, so a tapped checkbox can be found.
        var paragraphLocation: Int
        /// The paragraph's frame in text view coordinates.
        var frame: CGRect
        /// Baseline of the paragraph's first line, used to align markers.
        var baseline: CGFloat
        var indent: CGFloat
        /// Right-to-left paragraphs are indented, and so decorated, on the right.
        var isRightToLeft: Bool
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
    private var checkboxLayers: [CheckboxLayer] = []

    /// Layers currently shown, for tests and diagnostics.
    var renderedLayerCount: Int {
        (backgroundLayers + bulletLayers + numberLayers + checkboxLayers).filter { !$0.isHidden }.count
    }

    /// The paragraph location of the checklist item whose checkbox is at `point`, in this view's coordinates.
    ///
    /// Targets are up to 44 points tall so they're easy to hit, but never reach into a paragraph that isn't
    /// a checklist item, where a tap should place the caret. Between neighbouring items, the nearer checkbox wins.
    func checklistItem(at point: CGPoint) -> Int? {
        var best: (location: Int, distance: CGFloat)?
        for (index, decoration) in decorations.enumerated() {
            guard case .checkbox = decoration.kind else {
                continue
            }
            let box = checkboxFrame(for: decoration)
            var target = box.insetBy(dx: -8, dy: -max(4, (44 - box.height) / 2))
            let top = index > 0 && isAdjacentCheckbox(decorations[index - 1], to: decoration)
                ? target.minY : max(target.minY, decoration.frame.minY)
            let bottom = index + 1 < decorations.count && isAdjacentCheckbox(decorations[index + 1], to: decoration)
                ? target.maxY : min(target.maxY, decoration.frame.maxY)
            target = CGRect(x: target.minX, y: top, width: target.width, height: bottom - top)
            guard target.contains(point) else {
                continue
            }
            let distance = abs(point.y - box.midY)
            if best == nil || distance < best!.distance {
                best = (decoration.paragraphLocation, distance)
            }
        }
        return best?.location
    }

    private func isAdjacentCheckbox(_ neighbour: Decoration, to decoration: Decoration) -> Bool {
        guard case .checkbox = neighbour.kind else {
            return false
        }
        return abs(neighbour.frame.maxY - decoration.frame.minY) < 1 || abs(decoration.frame.maxY - neighbour.frame.minY) < 1
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
        var checkboxCount = 0

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
                let x = decoration.isRightToLeft ? decoration.frame.maxX - 3 : decoration.frame.minX
                layer.frame = CGRect(x: x, y: decoration.frame.minY, width: 3, height: decoration.frame.height)
                layer.cornerRadius = 1.5
                layer.backgroundColor = resolved(.tertiaryLabel)
                backgroundCount += 1
            case .bullet(let level):
                let layer = reusableLayer(at: bulletCount, in: &bulletLayers, make: CAShapeLayer.init)
                configureBullet(layer, level: level, for: decoration)
                bulletCount += 1
            case .checkbox(let isChecked):
                let layer = reusableLayer(at: checkboxCount, in: &checkboxLayers, make: CheckboxLayer.init)
                layer.frame = checkboxFrame(for: decoration)
                layer.configure(isChecked: isChecked, tint: resolved(tintColor), border: resolved(.tertiaryLabel), check: resolved(.white))
                checkboxCount += 1
            case .number(let ordinal):
                let layer = reusableLayer(at: numberCount, in: &numberLayers, make: CATextLayer.init)
                configureNumber(layer, ordinal: ordinal, for: decoration)
                numberCount += 1
            }
        }

        hideLayers(in: backgroundLayers, from: backgroundCount)
        hideLayers(in: bulletLayers, from: bulletCount)
        hideLayers(in: numberLayers, from: numberCount)
        hideLayers(in: checkboxLayers, from: checkboxCount)
    }

    /// A dot at the text side of the indent, centred on the x-height: filled, hollow, then square as lists nest.
    private func configureBullet(_ layer: CAShapeLayer, level: Int, for decoration: Decoration) {
        let font = markerFont(for: decoration)
        let diameter = (font.pointSize * 0.3).rounded()
        let distanceFromEdge = decoration.indent - 8 - diameter / 2
        let center = CGPoint(
            x: decoration.isRightToLeft ? decoration.frame.maxX - distanceFromEdge : decoration.frame.minX + distanceFromEdge,
            y: decoration.baseline - font.xHeight / 2
        )
        layer.frame = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        switch level % 3 {
        case 1:
            layer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 0.6, dy: 0.6)).cgPath
            layer.fillColor = nil
            layer.strokeColor = resolved(decoration.color)
            layer.lineWidth = 1.2
        case 2:
            layer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
            layer.fillColor = resolved(decoration.color)
            layer.strokeColor = nil
        default:
            layer.path = UIBezierPath(ovalIn: bounds).cgPath
            layer.fillColor = resolved(decoration.color)
            layer.strokeColor = nil
        }
    }

    /// A circle at the text side of the indent, centred on the cap height, like Notes.
    func checkboxFrame(for decoration: Decoration) -> CGRect {
        let font = markerFont(for: decoration)
        let size = (font.pointSize * 1.05).rounded()
        let distanceFromEdge = decoration.indent - 8 - size
        let x = decoration.isRightToLeft ? decoration.frame.maxX - distanceFromEdge - size : decoration.frame.minX + distanceFromEdge
        return CGRect(x: x, y: (decoration.baseline - font.capHeight / 2 - size / 2).rounded(), width: size, height: size)
    }

    /// "12." aligned against the text side of the indent, on the first line's baseline.
    private func configureNumber(_ layer: CATextLayer, ordinal: Int, for decoration: Decoration) {
        let font = markerFont(for: decoration)
        // Wide enough for "100."; the layer may extend past the text's edge, which is fine for an unclipped sublayer.
        let width: CGFloat = 60
        let textEdgeGap = decoration.indent - 6
        let x = decoration.isRightToLeft
            ? decoration.frame.maxX - textEdgeGap
            : decoration.frame.minX + textEdgeGap - width
        layer.frame = CGRect(x: x, y: decoration.baseline - font.ascender, width: width, height: font.lineHeight)
        layer.string = "\(ordinal)."
        // UIFont is toll-free bridged to CTFont; creating one by name would lose the system font.
        layer.font = font
        layer.fontSize = font.pointSize
        layer.foregroundColor = resolved(decoration.color)
        layer.alignmentMode = decoration.isRightToLeft ? .left : .right
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

/// A round checkbox: an outline when empty, a tinted disc with a checkmark when ticked.
private final class CheckboxLayer: CALayer {
    private let circle = CAShapeLayer()
    private let checkmark = CAShapeLayer()

    override init() {
        super.init()
        addSublayer(circle)
        addSublayer(checkmark)
        checkmark.fillColor = nil
        checkmark.lineCap = .round
        checkmark.lineJoin = .round
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isChecked: Bool, tint: CGColor, border: CGColor, check: CGColor) {
        let bounds = self.bounds
        circle.frame = bounds
        checkmark.frame = bounds
        let lineWidth = max(1.2, bounds.width / 12)
        circle.path = UIBezierPath(ovalIn: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)).cgPath
        circle.lineWidth = lineWidth
        circle.fillColor = isChecked ? tint : nil
        circle.strokeColor = isChecked ? tint : border

        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.width * 0.28, y: bounds.height * 0.52))
        path.addLine(to: CGPoint(x: bounds.width * 0.44, y: bounds.height * 0.68))
        path.addLine(to: CGPoint(x: bounds.width * 0.73, y: bounds.height * 0.36))
        checkmark.path = path.cgPath
        checkmark.lineWidth = lineWidth * 1.3
        checkmark.strokeColor = check
        checkmark.isHidden = !isChecked
    }
}
