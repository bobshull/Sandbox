import UIKit

final class CellButton: UIControl {

    var trackColor: UIColor = Theme.accent { didSet { updateAppearance() } }
    var accentColor: UIColor = Theme.accent { didSet { updateAppearance() } }
    var isOn: Bool = false { didSet { updateAppearance() } }
    var isPlayhead: Bool = false { didSet { updateAppearance() } }
    var isBeat: Bool = false { didSet { updateAppearance() } }

    private let backgroundLayer = CALayer()
    private let shadowLayer = CAGradientLayer()   // bottom darkening, always visible
    private let shineLayer = CAGradientLayer()    // top gloss highlight, always visible

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(backgroundLayer)
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        backgroundLayer.cornerRadius = 8
        backgroundLayer.cornerCurve = .continuous
        backgroundLayer.borderWidth = 1

        // Bottom-half shadow: clear → dark
        shadowLayer.startPoint = CGPoint(x: 0.5, y: 0.4)
        shadowLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        shadowLayer.cornerRadius = 8
        shadowLayer.cornerCurve = .continuous
        shadowLayer.masksToBounds = true
        backgroundLayer.addSublayer(shadowLayer)

        // Top-half gloss shine: bright → clear
        shineLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        shineLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        shineLayer.cornerRadius = 8
        shineLayer.cornerCurve = .continuous
        shineLayer.masksToBounds = true
        backgroundLayer.addSublayer(shineLayer)

        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame = bounds
        shadowLayer.frame = bounds
        shineLayer.frame = bounds
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.08) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.93, y: 0.93) : .identity
            }
        }
    }

    private func updateAppearance() {
        backgroundLayer.removeAnimation(forKey: "pulse")
        backgroundLayer.removeAnimation(forKey: "flash")
        backgroundLayer.removeAnimation(forKey: "bloom")

        if isOn {
            backgroundLayer.backgroundColor = trackColor.cgColor
            backgroundLayer.borderColor = accentColor.cgColor
            shineLayer.colors  = [UIColor.white.withAlphaComponent(0.30).cgColor,
                                   UIColor.white.withAlphaComponent(0.10).cgColor,
                                   UIColor.clear.cgColor]
            shineLayer.locations = [0, 0.35, 0.65]
            shadowLayer.colors = [UIColor.clear.cgColor,
                                   UIColor.black.withAlphaComponent(0.28).cgColor]
        } else if isBeat {
            backgroundLayer.backgroundColor = UIColor(red: 36/255, green: 43/255, blue: 62/255, alpha: 1).cgColor
            backgroundLayer.borderColor = UIColor(red: 52/255, green: 60/255, blue: 80/255, alpha: 1).cgColor
            shineLayer.colors  = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            shadowLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        } else {
            backgroundLayer.backgroundColor = Theme.backgroundElevated2.cgColor
            backgroundLayer.borderColor = Theme.border.cgColor
            shineLayer.colors  = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            shadowLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        }

        if isPlayhead && isOn {
            backgroundLayer.shadowColor = trackColor.cgColor
            backgroundLayer.shadowOpacity = 1.0
            backgroundLayer.shadowRadius = 12
            backgroundLayer.shadowOffset = .zero

            // Spring bounce: overshoot then snap back
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1.0, 1.18, 0.92, 1.0]
            scale.keyTimes = [0, 0.3, 0.65, 1.0]
            scale.duration = 0.38
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeOut),
            ]
            backgroundLayer.add(scale, forKey: "pulse")

            let flash = CABasicAnimation(keyPath: "backgroundColor")
            flash.fromValue = UIColor.white.withAlphaComponent(0.9).cgColor
            flash.toValue = trackColor.cgColor
            flash.duration = 0.32
            flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
            backgroundLayer.add(flash, forKey: "flash")

            // Glow bloom: shadow radius spikes then settles
            let bloom = CAKeyframeAnimation(keyPath: "shadowRadius")
            bloom.values = [12.0, 28.0, 10.0]
            bloom.keyTimes = [0, 0.3, 1.0]
            bloom.duration = 0.45
            bloom.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
            ]
            backgroundLayer.add(bloom, forKey: "bloom")
        } else if isPlayhead {
            backgroundLayer.shadowColor = Theme.accent2.cgColor
            backgroundLayer.shadowOpacity = 0.9
            backgroundLayer.shadowRadius = 8
            backgroundLayer.shadowOffset = .zero
        } else {
            backgroundLayer.shadowOpacity = 0
        }

        accessibilityValue = isOn ? "on" : "off"
    }

    // Brief glow pulse used by the Easter egg when tiles re-enter from the right.
    // No-ops on inactive cells; respects whatever shadow state updateAppearance set.
    func pulseReturn() {
        guard isOn else { return }
        let finalOpacity: Float = isPlayhead ? 1.0 : 0
        let finalRadius: CGFloat = isPlayhead ? 12 : 0
        // Commit final values to the model layer first so there's no snap on completion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.shadowColor = accentColor.cgColor
        backgroundLayer.shadowOpacity = finalOpacity
        backgroundLayer.shadowRadius = finalRadius
        CATransaction.commit()
        // Animate FROM brief glow TO resting state
        let opAnim = CABasicAnimation(keyPath: "shadowOpacity")
        opAnim.fromValue = Float(0.85)
        opAnim.toValue = finalOpacity
        opAnim.duration = 0.40
        opAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        backgroundLayer.add(opAnim, forKey: "eggGlow")

        let radAnim = CABasicAnimation(keyPath: "shadowRadius")
        radAnim.fromValue = CGFloat(20)
        radAnim.toValue = finalRadius
        radAnim.duration = 0.40
        radAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        backgroundLayer.add(radAnim, forKey: "eggRadius")
    }
}
