import UIKit

final class FaderControl: UIControl {

    var value: Float = 0 {
        didSet { value = min(max(value, minimumValue), maximumValue); setNeedsDisplay() }
    }
    var minimumValue: Float = 0
    var maximumValue: Float = 1
    var trackColor: UIColor = Theme.accent { didSet { setNeedsDisplay() } }
    var title: String = "" { didSet { setNeedsDisplay() } }
    var valueText: String = "" { didSet { setNeedsDisplay() } }

    /// Values that the fader snaps to when dragged within `snapRadius`.
    var snapPoints: [Float] = []
    var snapRadius: Float = 0

    private let capHeight: CGFloat = 22
    private let capWidth: CGFloat = 36
    private let trackWidth: CGFloat = 4

    private var dragOriginY: CGFloat = 0
    private var dragOriginValue: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { CGSize(width: 52, height: 160) }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cx = rect.midX

        let titleFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let valueFont = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let labelH: CGFloat = 16
        let segH: CGFloat = 4

        let trackTop = labelH + 14
        let trackBottom = rect.height - labelH - 14
        let trackH = trackBottom - trackTop

        let norm = CGFloat(min(max((value - minimumValue) / (maximumValue - minimumValue), 0), 1))
        let capCenterY = trackBottom - norm * trackH
        let fillTop = max(capCenterY, trackTop)

        // Background track
        let trackRect = CGRect(x: cx - trackWidth / 2, y: trackTop,
                               width: trackWidth, height: trackH)
        let trackPath = UIBezierPath(roundedRect: trackRect, cornerRadius: trackWidth / 2)
        Theme.border.withAlphaComponent(0.5).setFill()
        trackPath.fill()

        // Colored fill (cap to bottom)
        if norm > 0.005 {
            let fillRect = CGRect(x: cx - trackWidth / 2, y: fillTop,
                                  width: trackWidth, height: trackBottom - fillTop)
            let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: trackWidth / 2)
            trackColor.setFill()
            fillPath.fill()
        }

        // Fader cap
        let capRect = CGRect(x: cx - capWidth / 2, y: capCenterY - capHeight / 2,
                             width: capWidth, height: capHeight)
        let capPath = UIBezierPath(roundedRect: capRect, cornerRadius: 5)
        Theme.backgroundElevated2.setFill()
        capPath.fill()
        Theme.border.withAlphaComponent(0.7).setFill()
        ctx.setStrokeColor(Theme.border.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1)
        capPath.stroke()

        // Grip grooves (3 lines)
        ctx.setStrokeColor(Theme.textFaint.cgColor)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)
        for i in -1...1 {
            let gy = capCenterY + CGFloat(i) * 4
            ctx.move(to: CGPoint(x: cx - capWidth * 0.25, y: gy))
            ctx.addLine(to: CGPoint(x: cx + capWidth * 0.25, y: gy))
        }
        ctx.strokePath()

        // Segment tick marks
        let tickColor = Theme.border.withAlphaComponent(0.35)
        tickColor.setFill()
        for frac in stride(from: CGFloat(0), through: 1.0, by: 0.25) {
            let ty = trackTop + frac * trackH
            let tickRect = CGRect(x: cx + capWidth / 2 + 3, y: ty - segH / 2,
                                  width: 6, height: segH)
            UIBezierPath(roundedRect: tickRect, cornerRadius: 1).fill()
        }

        // Title label
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: Theme.textDim as Any
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttr)
        let titleSize = titleStr.size()
        titleStr.draw(at: CGPoint(x: cx - titleSize.width / 2, y: 0))

        // Value label
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: norm > 0.005 ? (trackColor as Any) : (Theme.textFaint as Any)
        ]
        let valStr = NSAttributedString(string: valueText, attributes: valAttr)
        let valSize = valStr.size()
        valStr.draw(at: CGPoint(x: cx - valSize.width / 2, y: rect.height - labelH))
    }

    // MARK: - Touch tracking

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        dragOriginY     = touch.location(in: self).y
        dragOriginValue = value
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let labelH: CGFloat = 16
        let trackTop    = labelH + 14
        let trackBottom = bounds.height - labelH - 14
        let trackH      = trackBottom - trackTop

        guard trackH > 0 else { return true }
        let dy    = dragOriginY - touch.location(in: self).y
        let delta = Float(dy / trackH) * (maximumValue - minimumValue)
        var raw   = min(max(dragOriginValue + delta, minimumValue), maximumValue)
        if snapRadius > 0, let snap = snapPoints.first(where: { abs(raw - $0) <= snapRadius }) {
            raw = snap
        }
        value = raw
        sendActions(for: .valueChanged)
        return true
    }
}
