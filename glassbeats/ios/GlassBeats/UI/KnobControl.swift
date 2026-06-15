import UIKit

final class KnobControl: UIControl {

    var value: Float = 0 {
        didSet { value = min(max(value, minimumValue), maximumValue); setNeedsDisplay() }
    }
    var minimumValue: Float = 0
    var maximumValue: Float = 1
    var trackColor: UIColor = Theme.accent { didSet { setNeedsDisplay() } }

    private var trackOriginY: CGFloat = 0
    private var trackOriginValue: Float = 0
    private let sensitivity: CGFloat = 160

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { CGSize(width: 64, height: 64) }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2 - 2
        let bodyR  = outerR - 8

        let start  = CGFloat.pi * 2.0 / 3.0
        let sweep  = CGFloat.pi * 5.0 / 3.0
        let end    = start + sweep
        let norm   = CGFloat(min(max((value - minimumValue) / (maximumValue - minimumValue), 0), 1))
        let valEnd = start + sweep * norm

        // Body
        ctx.setFillColor(Theme.backgroundElevated.cgColor)
        ctx.addEllipse(in: CGRect(x: center.x - bodyR, y: center.y - bodyR,
                                  width: bodyR * 2, height: bodyR * 2))
        ctx.fillPath()

        ctx.setStrokeColor(Theme.border.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(1)
        ctx.addEllipse(in: CGRect(x: center.x - bodyR, y: center.y - bodyR,
                                  width: bodyR * 2, height: bodyR * 2))
        ctx.strokePath()

        // Background arc
        ctx.setLineCap(.round)
        ctx.setLineWidth(4)
        ctx.setStrokeColor(Theme.border.withAlphaComponent(0.5).cgColor)
        ctx.addArc(center: center, radius: outerR - 2,
                   startAngle: start, endAngle: end, clockwise: false)
        ctx.strokePath()

        // Value arc
        if norm > 0.005 {
            ctx.setStrokeColor(trackColor.cgColor)
            ctx.addArc(center: center, radius: outerR - 2,
                       startAngle: start, endAngle: valEnd, clockwise: false)
            ctx.strokePath()
        }

        // Indicator line
        let lineInner = bodyR * 0.35
        let lineOuter = bodyR * 0.85
        ctx.setStrokeColor(Theme.text.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: center.x + lineInner * cos(valEnd),
                             y: center.y + lineInner * sin(valEnd)))
        ctx.addLine(to: CGPoint(x: center.x + lineOuter * cos(valEnd),
                                y: center.y + lineOuter * sin(valEnd)))
        ctx.strokePath()
    }

    // MARK: - UIControl tracking (works reliably inside UIScrollView)

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        trackOriginY     = touch.location(in: self).y
        trackOriginValue = value
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let dy = trackOriginY - touch.location(in: self).y
        value  = min(max(trackOriginValue + Float(dy / sensitivity) * (maximumValue - minimumValue),
                         minimumValue), maximumValue)
        sendActions(for: .valueChanged)
        return true
    }
}
