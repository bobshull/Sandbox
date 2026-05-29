import UIKit
import Combine

protocol TransportViewDelegate: AnyObject {
    func transportTogglePlay()
    func transportSetTempo(_ value: Double)
    func transportSetSwing(_ value: Double)
    func transportSetMaster(_ value: Float)
    func transportDidRequestPatternLength(_ length: Int)
}

final class TransportView: UIView {

    weak var delegate: TransportViewDelegate?

    private let playButton      = PlayButton()
    private let tempoSwingChip  = UIButton(type: .system)
    private let masterChip      = UIButton(type: .system)
    private let lengthChip      = UIButton(type: .system)

    /// Master pill shows the volume level as a very faint, theme-colored fill that
    /// grows left-to-right behind the speaker icon.
    private let masterFillLayer = CALayer()

    private var cancellables = Set<AnyCancellable>()
    private let store: Store
    private var isPlayingState = false

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        configure()
        applyState()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange),
                                               name: .colorThemeDidChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Source view for popovers/sheets that originate from the pattern-length chip.
    var patternLengthButton: UIView { lengthChip }

    // MARK: - Public

    func setIsPlaying(_ playing: Bool) {
        isPlayingState = playing
        let primary = ColorTheme.current.primaryColor
        var cfg = UIButton.Configuration.filled()
        cfg.background.cornerRadius = 8
        cfg.background.backgroundColor = playing ? Theme.backgroundElevated2 : primary
        cfg.background.strokeColor = playing ? primary : .clear
        cfg.background.strokeWidth = playing ? 1.5 : 0
        cfg.image = UIImage(systemName: playing ? "stop.fill" : "play.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        cfg.baseForegroundColor = playing ? primary : UIColor(white: 0.1, alpha: 1)
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        playButton.configuration = cfg
        playButton.setPlaying(playing)
    }

    @objc private func themeDidChange() {
        setIsPlaying(isPlayingState)
        syncLengthChip()
        masterChip.layer.backgroundColor = Theme.backgroundElevated.cgColor
        masterChip.layer.borderColor = Theme.border.cgColor
        updateMasterFill()
    }

    func observe(_ store: Store) {
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self else { return }
                switch section {
                case .tempo, .swing:
                    self.setTempoSwingChip(tempo: store.tempo, swing: store.swing)
                case .master:
                    self.setMasterChip()
                case .patternLength: self.syncLengthChip()
                case .load:
                    self.setTempoSwingChip(tempo: store.tempo, swing: store.swing)
                    self.setMasterChip()
                    self.syncLengthChip()
                default: break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Layout

    private func configure() {
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        setIsPlaying(false)
        addSubview(playButton)

        setupChip(tempoSwingChip, tag: 0, width: 120)
        setupChip(masterChip,     tag: 1, width: 52)
        setupChip(lengthChip,     tag: 2, width: 90)

        // Pill chrome is drawn on the chip's own layer so the fill can sit above the
        // background but below the icon, and clip to the rounded shape.
        masterChip.layer.backgroundColor = Theme.backgroundElevated.cgColor
        masterChip.layer.cornerRadius = 19
        masterChip.layer.borderColor = Theme.border.cgColor
        masterChip.layer.borderWidth = 1
        masterChip.clipsToBounds = true
        masterChip.layer.insertSublayer(masterFillLayer, at: 0)

        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            playButton.topAnchor.constraint(equalTo: topAnchor),
            playButton.heightAnchor.constraint(equalToConstant: 38),
            playButton.widthAnchor.constraint(equalToConstant: 54),

            tempoSwingChip.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            tempoSwingChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            masterChip.leadingAnchor.constraint(equalTo: tempoSwingChip.trailingAnchor, constant: 8),
            masterChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            lengthChip.leadingAnchor.constraint(equalTo: masterChip.trailingAnchor, constant: 8),
            lengthChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            bottomAnchor.constraint(equalTo: playButton.bottomAnchor),
        ])

        clipsToBounds = true
    }

    private func setupChip(_ button: UIButton, tag: Int, width: CGFloat) {
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        addSubview(button)
    }

    private func setMasterChip() {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: "speaker.wave.2",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        cfg.baseForegroundColor = Theme.text
        cfg.background.backgroundColor = .clear   // pill chrome is drawn on the chip's layer
        cfg.background.strokeColor = .clear
        cfg.background.strokeWidth = 0
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        masterChip.configuration = cfg
        updateMasterFill()
    }

    private func updateMasterFill() {
        masterFillLayer.backgroundColor = ColorTheme.current.primaryColor.withAlphaComponent(0.16).cgColor
        layoutMasterFill()
    }

    private func layoutMasterFill() {
        let level = CGFloat(min(max(store.masterGain, 0), 1))
        let b = masterChip.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        masterFillLayer.frame = CGRect(x: 0, y: 0, width: b.width * level, height: b.height)
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutMasterFill()
    }

    private func applyState() {
        setTempoSwingChip(tempo: store.tempo, swing: store.swing)
        setMasterChip()
        syncLengthChip()
    }

    private func setTempoSwingChip(tempo: Double, swing: Double) {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: "metronome",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        cfg.imagePadding = 5
        cfg.title = "\(Int(tempo.rounded())) BPM"
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs
            out.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            return out
        }
        cfg.baseForegroundColor = Theme.text
        cfg.background.backgroundColor = Theme.backgroundElevated
        cfg.background.strokeColor = Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 19
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
        tempoSwingChip.configuration = cfg
    }

    private func syncLengthChip() {
        let is32 = store.patternLength == 32
        let primary = ColorTheme.current.primaryColor
        var cfg = UIButton.Configuration.plain()
        cfg.title = is32 ? "2 Bars" : "1 Bar"
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs
            out.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            return out
        }
        cfg.baseForegroundColor = is32 ? primary : Theme.text
        cfg.background.backgroundColor = Theme.backgroundElevated
        cfg.background.strokeColor = is32 ? primary.withAlphaComponent(0.5) : Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 19
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        lengthChip.configuration = cfg
    }

    // MARK: - Actions

    @objc private func playTapped() {
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        delegate?.transportTogglePlay()
    }

    @objc private func chipTapped(_ sender: UIButton) {
        UISelectionFeedbackGenerator().selectionChanged()
        if sender.tag == 0 {
            showTempoSwing()
        } else if sender.tag == 1 {
            showSlider(from: sender, title: "Master", min: 0, max: 100, step: 1,
                       value: Double(store.masterGain) * 100, suffix: "%", icon: "speaker.wave.2") { [weak self] v in
                self?.delegate?.transportSetMaster(Float(v / 100))
            }
        } else {
            // Length chip — show 1 Bar / 2 Bars picker
            guard let parentVC = parentViewController else { return }
            let sheet = UIAlertController(title: "Pattern Length", message: nil, preferredStyle: .actionSheet)
            let mark16 = store.patternLength == 16 ? "✓ " : ""
            let mark32 = store.patternLength == 32 ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: "\(mark16)16 steps / 1 bar", style: .default) { [weak self] _ in
                self?.delegate?.transportDidRequestPatternLength(16)
            })
            sheet.addAction(UIAlertAction(title: "\(mark32)32 steps / 2 bars", style: .default) { [weak self] _ in
                self?.delegate?.transportDidRequestPatternLength(32)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            sheet.popoverPresentationController?.sourceView = sender
            parentVC.present(sheet, animated: true)
        }
    }

    private func showTempoSwing() {
        guard let parentVC = parentViewController else { return }
        let vc = TempoSwingPopoverViewController(tempo: store.tempo, swing: store.swing)
        vc.onTempoChange = { [weak self] v in
            guard let self else { return }
            self.setTempoSwingChip(tempo: v, swing: self.store.swing)
            self.delegate?.transportSetTempo(v)
        }
        vc.onSwingChange = { [weak self] v in
            guard let self else { return }
            self.setTempoSwingChip(tempo: self.store.tempo, swing: v / 100)
            self.delegate?.transportSetSwing(v / 100)
        }
        parentVC.present(vc, animated: true)
    }

    private func showSlider(from source: UIButton, title: String,
                            min: Double, max: Double, step: Double,
                            value: Double, suffix: String, icon: String,
                            onChange: @escaping (Double) -> Void) {
        guard let parentVC = parentViewController else { return }
        let vc = SliderPopoverViewController(title: title, min: min, max: max,
                                             step: step, value: value, suffix: suffix, icon: icon)
        vc.onChange = onChange
        parentVC.present(vc, animated: true)
    }
}

// MARK: - SliderPopoverViewController

final class SliderPopoverViewController: UIViewController {

    var onChange: ((Double) -> Void)?

    private let controlTitle: String
    private let minVal: Double
    private let maxVal: Double
    private let step: Double
    private var current: Double
    private let suffix: String
    private let icon: String

    private let panel = UIView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    init(title: String, min: Double, max: Double, step: Double,
         value: Double, suffix: String, icon: String) {
        self.controlTitle = title
        self.minVal  = min
        self.maxVal  = max
        self.step    = step
        self.current = value
        self.suffix  = suffix
        self.icon    = icon
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let bg = UIButton(type: .custom)
        bg.frame = view.bounds
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bg.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        view.addSubview(bg)

        let primary = ColorTheme.current.primaryColor
        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = primary.withAlphaComponent(0.75).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iconView.tintColor = primary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(iconView)

        titleLabel.text = controlTitle
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = primary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        valueLabel.text = format(current)
        valueLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        valueLabel.textColor = Theme.text
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(valueLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textFaint
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(closeButton)

        slider.minimumValue = Float(minVal)
        slider.maximumValue = Float(maxVal)
        slider.value = Float(current)
        slider.minimumTrackTintColor = primary
        slider.maximumTrackTintColor = Theme.border
        let grip = Theme.makeGripThumb()
        slider.setThumbImage(grip, for: .normal)
        slider.setThumbImage(grip, for: .highlighted)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(slider)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 380),

            iconView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            iconView.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 70),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            slider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            slider.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    @objc private func dismissOverlay() { dismiss(animated: true) }

    @objc private func sliderChanged() {
        let snapped = step > 0 ? (Double(slider.value) / step).rounded() * step : Double(slider.value)
        current = snapped
        valueLabel.text = format(snapped)
        onChange?(snapped)
    }

    private func format(_ v: Double) -> String {
        "\(Int(v.rounded()))\(suffix)"
    }
}

// MARK: - TempoSwingPopoverViewController

final class TempoSwingPopoverViewController: UIViewController {

    var onTempoChange: ((Double) -> Void)?
    var onSwingChange: ((Double) -> Void)?

    private var currentTempo: Double
    private var currentSwing: Double   // 0–60 (percent)

    private let panel = UIView()
    private let tempoValueLabel = UILabel()
    private let swingValueLabel = UILabel()
    private let tempoSlider = UISlider()
    private let swingSlider = UISlider()

    init(tempo: Double, swing: Double) {
        self.currentTempo = tempo
        self.currentSwing = swing * 100
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let bg = UIButton(type: .custom)
        bg.frame = view.bounds
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bg.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        view.addSubview(bg)

        let primary = ColorTheme.current.primaryColor
        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = primary.withAlphaComponent(0.75).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textFaint
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(closeButton)

        // ── Tempo row ──────────────────────────────────────────────────────
        let tempoIcon = makeIcon("metronome", tint: primary)
        let tempoLabel = makeLabel("Tempo", color: primary)
        tempoValueLabel.text = "\(Int(currentTempo.rounded())) BPM"
        tempoValueLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        tempoValueLabel.textColor = Theme.text
        tempoValueLabel.textAlignment = .right
        tempoValueLabel.translatesAutoresizingMaskIntoConstraints = false

        tempoSlider.minimumValue = 60
        tempoSlider.maximumValue = 200
        tempoSlider.value = Float(currentTempo)
        styleSlider(tempoSlider, primary: primary)
        tempoSlider.addTarget(self, action: #selector(tempoChanged), for: .valueChanged)

        // ── Swing row ──────────────────────────────────────────────────────
        let swingIcon = makeIcon("waveform.path", tint: primary)
        let swingLabel = makeLabel("Swing", color: primary)
        swingValueLabel.text = "\(Int(currentSwing.rounded()))%"
        swingValueLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        swingValueLabel.textColor = Theme.text
        swingValueLabel.textAlignment = .right
        swingValueLabel.translatesAutoresizingMaskIntoConstraints = false

        swingSlider.minimumValue = 0
        swingSlider.maximumValue = 60
        swingSlider.value = Float(currentSwing)
        styleSlider(swingSlider, primary: primary)
        swingSlider.addTarget(self, action: #selector(swingChanged), for: .valueChanged)

        for v in [tempoIcon, tempoLabel, tempoValueLabel, tempoSlider,
                  swingIcon, swingLabel, swingValueLabel, swingSlider] {
            panel.addSubview(v)
        }

        let divider = UIView()
        divider.backgroundColor = Theme.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(divider)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 380),

            closeButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            // Tempo section
            tempoIcon.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            tempoIcon.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            tempoIcon.widthAnchor.constraint(equalToConstant: 18),
            tempoIcon.heightAnchor.constraint(equalToConstant: 18),

            tempoLabel.leadingAnchor.constraint(equalTo: tempoIcon.trailingAnchor, constant: 8),
            tempoLabel.centerYAnchor.constraint(equalTo: tempoIcon.centerYAnchor),

            tempoValueLabel.centerYAnchor.constraint(equalTo: tempoIcon.centerYAnchor),
            tempoValueLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            tempoValueLabel.widthAnchor.constraint(equalToConstant: 80),

            tempoSlider.topAnchor.constraint(equalTo: tempoIcon.bottomAnchor, constant: 12),
            tempoSlider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            tempoSlider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),

            // Divider
            divider.topAnchor.constraint(equalTo: tempoSlider.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Swing section
            swingIcon.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            swingIcon.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            swingIcon.widthAnchor.constraint(equalToConstant: 18),
            swingIcon.heightAnchor.constraint(equalToConstant: 18),

            swingLabel.leadingAnchor.constraint(equalTo: swingIcon.trailingAnchor, constant: 8),
            swingLabel.centerYAnchor.constraint(equalTo: swingIcon.centerYAnchor),

            swingValueLabel.centerYAnchor.constraint(equalTo: swingIcon.centerYAnchor),
            swingValueLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            swingValueLabel.widthAnchor.constraint(equalToConstant: 80),

            swingSlider.topAnchor.constraint(equalTo: swingIcon.bottomAnchor, constant: 12),
            swingSlider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            swingSlider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            swingSlider.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    @objc private func dismissOverlay() { dismiss(animated: true) }

    @objc private func tempoChanged() {
        let snapped = Double(tempoSlider.value).rounded()
        currentTempo = snapped
        tempoValueLabel.text = "\(Int(snapped)) BPM"
        onTempoChange?(snapped)
    }

    @objc private func swingChanged() {
        let snapped = Double(swingSlider.value).rounded()
        currentSwing = snapped
        swingValueLabel.text = "\(Int(snapped))%"
        onSwingChange?(snapped)
    }

    private func makeIcon(_ name: String, tint: UIColor) -> UIImageView {
        let iv = UIImageView(image: UIImage(systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iv.tintColor = tint
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }

    private func makeLabel(_ text: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func styleSlider(_ s: UISlider, primary: UIColor) {
        s.minimumTrackTintColor = primary
        s.maximumTrackTintColor = Theme.border
        let grip = Theme.makeGripThumb()
        s.setThumbImage(grip, for: .normal)
        s.setThumbImage(grip, for: .highlighted)
        s.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - PlayButton

private final class PlayButton: UIButton {
    private let shineLayer  = CAGradientLayer()
    private let shadowLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shineLayer.startPoint    = CGPoint(x: 0.5, y: 0.0)
        shineLayer.endPoint      = CGPoint(x: 0.5, y: 1.0)
        shineLayer.colors        = [UIColor.white.withAlphaComponent(0.30).cgColor,
                                    UIColor.white.withAlphaComponent(0.10).cgColor,
                                    UIColor.clear.cgColor]
        shineLayer.locations     = [0, 0.35, 0.65]
        shineLayer.cornerRadius  = 8
        shineLayer.cornerCurve   = .continuous
        shineLayer.masksToBounds = true

        shadowLayer.startPoint    = CGPoint(x: 0.5, y: 0.4)
        shadowLayer.endPoint      = CGPoint(x: 0.5, y: 1.0)
        shadowLayer.colors        = [UIColor.clear.cgColor,
                                     UIColor.black.withAlphaComponent(0.28).cgColor]
        shadowLayer.cornerRadius  = 8
        shadowLayer.cornerCurve   = .continuous
        shadowLayer.masksToBounds = true

        layer.addSublayer(shineLayer)
        layer.addSublayer(shadowLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPlaying(_ playing: Bool) {
        shineLayer.opacity = playing ? 0 : 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shineLayer.frame  = bounds
        shadowLayer.frame = bounds
    }
}

// MARK: - Responder helper

private extension UIResponder {
    var parentViewController: UIViewController? {
        next as? UIViewController ?? next?.parentViewController
    }
}
