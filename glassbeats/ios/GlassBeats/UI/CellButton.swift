import UIKit

final class CellButton: UIControl {

    // oldValue guards matter here: sync passes (notably syncPlayhead, which runs
    // for every cell on every step event) reassign these constantly, and the
    // full layer rebuild in updateAppearance is wasted work for no-op writes.
    var trackColor: UIColor = Theme.accent { didSet { guard oldValue != trackColor else { return }; updateAppearance() } }
    var accentColor: UIColor = Theme.accent { didSet { guard oldValue != accentColor else { return }; updateAppearance() } }
    var isOn: Bool = false { didSet { guard oldValue != isOn else { return }; updateAppearance() } }
    var isPlayhead: Bool = false { didSet { guard oldValue != isPlayhead else { return }; updateAppearance() } }
    var isBeat: Bool = false { didSet { guard oldValue != isBeat else { return }; updateAppearance() } }
    var isAccented: Bool = false { didSet { guard oldValue != isAccented else { return }; updateAppearance() } }
    /// Per-step semitone offset for pitch-capable tracks; nil for drum tracks.
    /// Raised shows an up triangle, lowered a down triangle, default a square.
    var pitchOffset: Int? = nil { didSet { guard oldValue != pitchOffset else { return }; updateAppearance() } }

    private let backgroundLayer = CALayer()
    private let shadowLayer = CAGradientLayer()   // bottom darkening, always visible
    private let shineLayer = CAGradientLayer()    // top gloss highlight, always visible
    private let accentDot = CALayer()             // small corner marker for accented steps
    private let pitchMarker = CAShapeLayer()      // small corner triangle for pitch-varied steps

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

        // Accent dot: small marker in the bottom-left corner, matching the
        // pitch marker's weight so all step indicators share one visual family.
        accentDot.backgroundColor = UIColor.white.withAlphaComponent(0.75).cgColor
        accentDot.cornerRadius = 2.5
        accentDot.isHidden = true
        backgroundLayer.addSublayer(accentDot)

        // Pitch marker: small triangle in bottom-right corner, points up for a
        // raised step and down for a lowered one. Hidden at the default pitch.
        pitchMarker.fillColor = UIColor.white.withAlphaComponent(0.75).cgColor
        pitchMarker.isHidden = true
        backgroundLayer.addSublayer(pitchMarker)

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
        layoutStepIndicators()
        updatePitchMarkerPath()
    }

    /// Step indicators sit side by side in the bottom-right corner, right-aligned:
    /// visible markers pack against the right edge with the pitch triangle outermost.
    /// Inset enough to clear the cell's rounded corner.
    private func layoutStepIndicators() {
        let margin: CGFloat = 4
        let gap: CGFloat = 3
        let markerSize: CGFloat = 7
        let dotSize: CGFloat = 5
        var x = bounds.width - margin
        if !pitchMarker.isHidden {
            x -= markerSize
            pitchMarker.frame = CGRect(x: x,
                                       y: bounds.height - markerSize - margin,
                                       width: markerSize, height: markerSize)
            x -= gap
        }
        if !accentDot.isHidden {
            x -= dotSize
            // Vertically centered against the triangle for an even baseline.
            accentDot.frame = CGRect(x: x,
                                     y: bounds.height - margin - markerSize / 2 - dotSize / 2,
                                     width: dotSize, height: dotSize)
        }
    }

    private func updatePitchMarkerPath() {
        let size = pitchMarker.bounds.size
        guard size.width > 0 else { return }
        let offset = pitchOffset ?? 0
        if offset == 0 {
            // Mid/default: small square, inset so its weight matches the triangles
            pitchMarker.path = UIBezierPath(rect: CGRect(x: 1, y: 1,
                                                         width: size.width - 2,
                                                         height: size.height - 2)).cgPath
            return
        }
        let path = UIBezierPath()
        if offset > 0 {
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        }
        path.close()
        pitchMarker.path = path.cgPath
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.08) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.93, y: 0.93) : .identity
            }
        }
    }

    private func updateAppearance() {
        backgroundLayer.removeAnimation(forKey: "playheadBounce")
        backgroundLayer.removeAnimation(forKey: "flash")
        backgroundLayer.removeAnimation(forKey: "bloom")

        if isOn {
            // Accent reads as a brighter fill + corner dot; no border or glow
            // emphasis, so accented cells sit flush with the rest of the grid.
            let fillColor = isAccented ? trackColor.brightened(by: 0.22) : trackColor
            backgroundLayer.backgroundColor = fillColor.cgColor
            backgroundLayer.borderColor = accentColor.cgColor
            backgroundLayer.borderWidth = 1.0
            shineLayer.colors = [UIColor.white.withAlphaComponent(0.30).cgColor,
                                 UIColor.white.withAlphaComponent(0.10).cgColor,
                                 UIColor.clear.cgColor]
            shineLayer.locations = [0, 0.35, 0.65]
            shadowLayer.colors = [UIColor.clear.cgColor,
                                   UIColor.black.withAlphaComponent(0.28).cgColor]
        } else if isBeat {
            backgroundLayer.borderWidth = 1.0
            backgroundLayer.backgroundColor = UIColor(red: 36/255, green: 43/255, blue: 62/255, alpha: 1).cgColor
            backgroundLayer.borderColor = UIColor(red: 52/255, green: 60/255, blue: 80/255, alpha: 1).cgColor
            shineLayer.colors  = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            shadowLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        } else {
            backgroundLayer.borderWidth = 1.0
            backgroundLayer.backgroundColor = Theme.backgroundElevated2.cgColor
            backgroundLayer.borderColor = Theme.border.cgColor
            shineLayer.colors  = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            shadowLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        }

        // Commit shadow state instantly — no implicit animation — so the glow
        // never gets stuck between transitions (e.g. accent removal mid-playhead).
        let glowRadius: CGFloat = 12
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isPlayhead && isOn {
            backgroundLayer.shadowColor = trackColor.cgColor
            backgroundLayer.shadowOpacity = 1.0
            backgroundLayer.shadowRadius = glowRadius
            backgroundLayer.shadowOffset = .zero
        } else if isPlayhead {
            backgroundLayer.shadowColor = Theme.accent2.cgColor
            backgroundLayer.shadowOpacity = 0.9
            backgroundLayer.shadowRadius = 8
            backgroundLayer.shadowOffset = .zero
        } else {
            backgroundLayer.shadowOpacity = 0
        }
        CATransaction.commit()

        // Explicit animations run after the model layer is committed above.
        if isPlayhead && isOn {
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
            backgroundLayer.add(scale, forKey: "playheadBounce")

            let flash = CABasicAnimation(keyPath: "backgroundColor")
            flash.fromValue = UIColor.white.withAlphaComponent(0.9).cgColor
            flash.toValue = (isAccented ? trackColor.brightened(by: 0.22) : trackColor).cgColor
            flash.duration = 0.32
            flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
            backgroundLayer.add(flash, forKey: "flash")

            // Glow bloom: shadow radius spikes then settles
            let bloom = CAKeyframeAnimation(keyPath: "shadowRadius")
            bloom.values = [glowRadius, glowRadius + 16.0, glowRadius - 2.0]
            bloom.keyTimes = [0, 0.3, 1.0]
            bloom.duration = 0.45
            bloom.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
            ]
            backgroundLayer.add(bloom, forKey: "bloom")
        }

        accentDot.isHidden = !isOn || !isAccented
        pitchMarker.isHidden = !isOn || pitchOffset == nil
        layoutStepIndicators()
        updatePitchMarkerPath()
        var value = isOn ? (isAccented ? "on accented" : "on") : "off"
        if isOn, let offset = pitchOffset, offset != 0 {
            value += offset > 0 ? " pitch raised" : " pitch lowered"
        }
        accessibilityValue = value
    }

    // Accent toggle feedback animation — call after store.toggleAccent.
    func accentBeat(on: Bool) {
        guard isOn else { return }
        if on {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1.0, 1.15, 0.95, 1.0]
            scale.keyTimes = [0, 0.25, 0.65, 1.0]
            scale.duration = 0.32
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeOut),
            ]
            backgroundLayer.add(scale, forKey: "accentBeat")

            let flash = CABasicAnimation(keyPath: "backgroundColor")
            flash.fromValue = UIColor.white.withAlphaComponent(0.85).cgColor
            flash.toValue = trackColor.brightened(by: 0.22).cgColor
            flash.duration = 0.28
            flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
            backgroundLayer.add(flash, forKey: "accentFlash")
        } else {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1.0, 0.88, 1.0]
            scale.keyTimes = [0, 0.4, 1.0]
            scale.duration = 0.22
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .easeOut),
            ]
            backgroundLayer.add(scale, forKey: "accentBeat")
        }
    }

    // Brief glow used by the Easter egg when tiles re-enter from the right.
    // MARK: - Easter egg return glow
    // No-ops on inactive cells; respects whatever shadow state updateAppearance set.
    func returnGlow() {
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

// MARK: -

private extension UIColor {
    /// Returns a brighter version by boosting brightness and slightly desaturating.
    func brightened(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h,
                           saturation: max(s - amount * 0.3, 0),
                           brightness: min(b + amount, 1.0),
                           alpha: a)
        }
        // Fallback for achromatic colors
        var w: CGFloat = 0
        getWhite(&w, alpha: &a)
        return UIColor(white: min(w + amount, 1.0), alpha: a)
    }
}
