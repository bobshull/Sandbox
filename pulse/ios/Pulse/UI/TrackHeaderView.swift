import UIKit

protocol TrackHeaderViewDelegate: AnyObject {
    func trackHeaderDidTapPreview(_ track: Track)
    func trackHeaderDidToggleMute(_ track: Track)
    func trackHeaderDidChangeVolume(_ track: Track, value: Float)
    func trackHeaderDidChangeEffects(_ track: Track, effects: TrackEffects)
}

final class TrackHeaderView: UIView {
    let track: Track
    weak var delegate: TrackHeaderViewDelegate?

    private let swatchButton = UIButton(type: .system)
    private let muteButton = WideHitButton(type: .system)
    private let volumePill = VolumePillControl()
    private var currentVolume: Float = 0.8
    private var currentEffects: TrackEffects = .default

    init(track: Track) {
        self.track = track
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setMuted(_ muted: Bool) {
        let symCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let img = UIImage(systemName: muted ? "speaker.slash.fill" : "speaker.fill",
                          withConfiguration: symCfg)
        muteButton.setImage(img, for: .normal)
        muteButton.tintColor = muted ? Theme.danger : Theme.textFaint
        muteButton.layer.borderColor = (muted ? Theme.danger : Theme.border).cgColor
    }

    func setVolume(_ value: Float) {
        currentVolume = value
        volumePill.progress = CGFloat(value)
        updatePillLabel()
    }

    func setEffects(_ fx: TrackEffects) {
        currentEffects = fx
        updatePillLabel()
    }

    func applyThemeColor(_ color: UIColor) {
        var cfg = swatchButton.configuration
        cfg?.background.backgroundColor = color
        swatchButton.configuration = cfg
        volumePill.fillColor = color
    }

    private func updatePillLabel() {
        let pct = "\(Int((currentVolume * 100).rounded()))%"
        volumePill.label.text = currentEffects.hasAnyActive ? "• \(pct)" : pct
    }

    // MARK: - Layout

    private func configure() {
        backgroundColor = Theme.backgroundElevated2
        layer.cornerRadius = Theme.cornerSmall
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor

        var swatchCfg = UIButton.Configuration.plain()
        swatchCfg.title = track.name
        swatchCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = .systemFont(ofSize: 9, weight: .bold); return out
        }
        swatchCfg.baseForegroundColor = UIColor(white: 0.1, alpha: 0.9)
        swatchCfg.background.backgroundColor = track.color
        swatchCfg.background.cornerRadius = 4
        swatchCfg.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)
        swatchButton.configuration = swatchCfg
        swatchButton.translatesAutoresizingMaskIntoConstraints = false
        swatchButton.accessibilityLabel = "Preview \(track.name)"
        swatchButton.addTarget(self, action: #selector(previewTapped), for: .touchUpInside)
        addSubview(swatchButton)

        let symCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        muteButton.setImage(UIImage(systemName: "speaker.fill", withConfiguration: symCfg), for: .normal)
        muteButton.tintColor = Theme.textFaint
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.layer.cornerRadius = 4
        muteButton.layer.borderWidth = 1
        muteButton.layer.borderColor = Theme.border.cgColor
        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        muteButton.accessibilityLabel = "Mute \(track.name)"
        addSubview(muteButton)

        volumePill.fillColor = track.color
        volumePill.translatesAutoresizingMaskIntoConstraints = false
        volumePill.accessibilityLabel = "\(track.name) volume"
        volumePill.addTarget(self, action: #selector(volumeTapped), for: .touchUpInside)
        addSubview(volumePill)
        setVolume(currentVolume)

        NSLayoutConstraint.activate([
            swatchButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            swatchButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            swatchButton.widthAnchor.constraint(equalToConstant: 40),

            muteButton.leadingAnchor.constraint(equalTo: swatchButton.trailingAnchor, constant: 6),
            muteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 22),
            muteButton.heightAnchor.constraint(equalToConstant: 22),

            volumePill.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 6),
            volumePill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            volumePill.centerYAnchor.constraint(equalTo: centerYAnchor),
            volumePill.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @objc private func previewTapped() {
        UISelectionFeedbackGenerator().selectionChanged()
        delegate?.trackHeaderDidTapPreview(track)
    }

    @objc private func muteTapped() {
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        delegate?.trackHeaderDidToggleMute(track)
    }

    @objc private func volumeTapped() {
        guard let parentVC = parentViewController else { return }
        let vc = TrackDetailViewController(track: track, volume: currentVolume, effects: currentEffects)
        vc.onVolumeChange = { [weak self] value in
            guard let self else { return }
            self.setVolume(value)
            self.delegate?.trackHeaderDidChangeVolume(self.track, value: value)
        }
        vc.onEffectsChange = { [weak self] fx in
            guard let self else { return }
            self.setEffects(fx)
            self.delegate?.trackHeaderDidChangeEffects(self.track, effects: fx)
        }
        parentVC.present(vc, animated: true)
    }
}

// MARK: - VolumePillControl

final class VolumePillControl: UIControl {
    private let fillView = UIView()
    let label = UILabel()

    var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    var fillColor: UIColor = Theme.accent {
        didSet { fillView.backgroundColor = fillColor.withAlphaComponent(0.35) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.backgroundElevated2
        layer.cornerRadius = 4
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor
        clipsToBounds = true

        fillView.backgroundColor = Theme.accent.withAlphaComponent(0.35)
        fillView.isUserInteractionEnabled = false
        addSubview(fillView)

        label.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        label.isUserInteractionEnabled = false
        label.textColor = Theme.text
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillView.frame = CGRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height)
        CATransaction.commit()
    }
}

// MARK: - WideHitButton

private final class WideHitButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -14, dy: -14).contains(point)
    }
}

// MARK: - Helpers

private extension UIResponder {
    var parentViewController: UIViewController? {
        next as? UIViewController ?? next?.parentViewController
    }
}

