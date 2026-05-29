import UIKit

// MARK: - Strip

final class LevelMeterStripView: UIView {

    private var bars: [LevelMeterBar] = []
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: Tracks.all.map { track in
            let bar = LevelMeterBar(track: track)
            bars.append(bar)
            return bar
        })
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .colorThemeDidChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
        displayLink?.invalidate()
    }

    @objc private func applyTheme() {
        bars.forEach { $0.applyThemeColor(ColorTheme.current.color(for: $0.trackId)) }
    }

    func trigger(trackId: String) {
        guard let bar = bars.first(where: { $0.trackId == trackId }) else { return }
        bar.trigger()
        guard displayLink == nil else { return }
        let dl = CADisplayLink(target: self, selector: #selector(tick))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    @objc private func tick() {
        bars.forEach { $0.tick() }
        if bars.allSatisfy({ !$0.isDecaying }) {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}

// MARK: - Single bar

final class LevelMeterBar: UIView {

    let trackId: String
    private var trackColor: UIColor

    private let bgLayer   = CALayer()
    private let fillLayer = CALayer()
    private let peakLayer = CALayer()
    private let nameLabel = UILabel()

    private var level: CGFloat = 0
    private var peakLevel: CGFloat = 0
    private var peakHold = 0

    private let labelH: CGFloat = 16

    var isDecaying: Bool { level > 0.002 }

    init(track: Track) {
        trackId    = track.id
        trackColor = ColorTheme.current.color(for: track.id)
        super.init(frame: .zero)

        bgLayer.backgroundColor = trackColor.withAlphaComponent(0.10).cgColor
        bgLayer.cornerRadius = 5
        bgLayer.cornerCurve  = .continuous
        layer.addSublayer(bgLayer)

        fillLayer.backgroundColor = trackColor.cgColor
        fillLayer.cornerRadius = 5
        fillLayer.cornerCurve  = .continuous
        layer.addSublayer(fillLayer)

        // Bright accent line that marks the recent peak
        peakLayer.backgroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
        peakLayer.cornerRadius = 1
        peakLayer.isHidden = true
        layer.addSublayer(peakLayer)

        nameLabel.text      = track.name
        nameLabel.font      = .systemFont(ofSize: 10, weight: .semibold)
        nameLabel.textColor = trackColor.withAlphaComponent(0.55)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: labelH),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        bgLayer.frame = barRect
        redraw()
    }

    func applyThemeColor(_ color: UIColor) {
        trackColor = color
        bgLayer.backgroundColor = color.withAlphaComponent(0.10).cgColor
        fillLayer.backgroundColor = color.cgColor
        nameLabel.textColor = color.withAlphaComponent(0.55)
    }

    private var barH: CGFloat { bounds.height - labelH - 4 }
    private var barRect: CGRect { CGRect(x: 0, y: 0, width: bounds.width, height: barH) }

    func trigger() {
        level     = CGFloat.random(in: 0.80...1.0)
        peakLevel = level
        peakHold  = 10
        redraw()
    }

    func tick() {
        guard level > 0.002 else {
            level = 0; peakLevel = 0
            redraw(); return
        }
        level *= 0.87
        if peakHold > 0 {
            peakHold -= 1
        } else {
            peakLevel = max(peakLevel * 0.93, level)
        }
        redraw()
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let h  = barH * level
        fillLayer.frame = CGRect(x: 0, y: barH - h, width: bounds.width, height: max(h, 0))

        if peakLevel > 0.04 {
            peakLayer.frame   = CGRect(x: 0, y: barH * (1 - peakLevel), width: bounds.width, height: 2)
            peakLayer.isHidden = false
        } else {
            peakLayer.isHidden = true
        }

        // Glow scales with level — hotter = brighter bleed
        if level > 0.35 {
            fillLayer.shadowColor   = trackColor.cgColor
            fillLayer.shadowOpacity = Float((level - 0.35) / 0.65 * 0.9)
            fillLayer.shadowRadius  = 10
            fillLayer.shadowOffset  = .zero
        } else {
            fillLayer.shadowOpacity = 0
        }

        CATransaction.commit()
    }
}
