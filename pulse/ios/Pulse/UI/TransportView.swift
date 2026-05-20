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

    private let playButton  = UIButton(type: .system)
    private let tempoChip   = UIButton(type: .system)
    private let swingChip   = UIButton(type: .system)
    private let masterChip  = UIButton(type: .system)
    private let lengthChip  = UIButton(type: .system)

    private var cancellables = Set<AnyCancellable>()
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        configure()
        applyState()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func setIsPlaying(_ playing: Bool) {
        var cfg = UIButton.Configuration.filled()
        cfg.background.cornerRadius = 8
        cfg.background.backgroundColor = playing ? Theme.backgroundElevated2 : Theme.accent
        cfg.background.strokeColor = playing ? Theme.accent : .clear
        cfg.background.strokeWidth = playing ? 1.5 : 0
        cfg.image = UIImage(systemName: playing ? "stop.fill" : "play.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        cfg.baseForegroundColor = playing ? Theme.accent : UIColor(white: 0.1, alpha: 1)
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        playButton.configuration = cfg
    }

    func observe(_ store: Store) {
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self else { return }
                switch section {
                case .tempo:  self.setChip(self.tempoChip, value: store.tempo, suffix: " BPM", icon: "metronome")
                case .swing:  self.setChip(self.swingChip, value: store.swing * 100, suffix: "%", icon: "waveform.path")
                case .master: self.setChip(self.masterChip, value: Double(store.masterGain) * 100, suffix: "%", icon: "speaker.wave.2")
                case .patternLength: self.syncLengthChip()
                case .load:
                    self.setChip(self.tempoChip, value: store.tempo, suffix: " BPM", icon: "metronome")
                    self.setChip(self.swingChip, value: store.swing * 100, suffix: "%", icon: "waveform.path")
                    self.setChip(self.masterChip, value: Double(store.masterGain) * 100, suffix: "%", icon: "speaker.wave.2")
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

        setupChip(tempoChip, tag: 0, width: 120)
        setupChip(swingChip, tag: 1, width: 105)
        setupChip(masterChip, tag: 2, width: 90)
        setupChip(lengthChip, tag: 3, width: 90)

        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            playButton.topAnchor.constraint(equalTo: topAnchor),
            playButton.heightAnchor.constraint(equalToConstant: 38),
            playButton.widthAnchor.constraint(equalToConstant: 54),

            tempoChip.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            tempoChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            swingChip.leadingAnchor.constraint(equalTo: tempoChip.trailingAnchor, constant: 8),
            swingChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            masterChip.leadingAnchor.constraint(equalTo: swingChip.trailingAnchor, constant: 8),
            masterChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            lengthChip.leadingAnchor.constraint(equalTo: masterChip.trailingAnchor, constant: 8),
            lengthChip.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            bottomAnchor.constraint(equalTo: playButton.bottomAnchor),
        ])
    }

    private func setupChip(_ button: UIButton, tag: Int, width: CGFloat) {
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        addSubview(button)
    }

    private func setChip(_ button: UIButton, value: Double, suffix: String, icon: String) {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        cfg.imagePadding = 5
        cfg.title = "\(Int(value.rounded()))\(suffix)"
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
        button.configuration = cfg
    }

    private func applyState() {
        setChip(tempoChip,  value: store.tempo,              suffix: " BPM", icon: "metronome")
        setChip(swingChip,  value: store.swing * 100,        suffix: "%",    icon: "waveform.path")
        setChip(masterChip, value: Double(store.masterGain) * 100, suffix: "%", icon: "speaker.wave.2")
        syncLengthChip()
    }

    private func syncLengthChip() {
        let is32 = store.patternLength == 32
        var cfg = UIButton.Configuration.plain()
        cfg.title = is32 ? "2 Bars" : "1 Bar"
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs
            out.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            return out
        }
        cfg.baseForegroundColor = is32 ? Theme.accent : Theme.text
        cfg.background.backgroundColor = Theme.backgroundElevated
        cfg.background.strokeColor = is32 ? Theme.accent.withAlphaComponent(0.5) : Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 19
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        lengthChip.configuration = cfg
    }

    // MARK: - Actions

    @objc private func playTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.transportTogglePlay()
    }

    @objc private func chipTapped(_ sender: UIButton) {
        UISelectionFeedbackGenerator().selectionChanged()
        if sender.tag == 0 {
            showSlider(from: sender, title: "Tempo", min: 60, max: 200, step: 1,
                       value: store.tempo, suffix: " BPM", icon: "metronome") { [weak self] v in
                guard let self else { return }
                self.setChip(self.tempoChip, value: v, suffix: " BPM", icon: "metronome")
                self.delegate?.transportSetTempo(v)
            }
        } else if sender.tag == 1 {
            showSlider(from: sender, title: "Swing", min: 0, max: 60, step: 1,
                       value: store.swing * 100, suffix: "%", icon: "waveform.path") { [weak self] v in
                guard let self else { return }
                self.setChip(self.swingChip, value: v, suffix: "%", icon: "waveform.path")
                self.delegate?.transportSetSwing(v / 100)
            }
        } else if sender.tag == 2 {
            showSlider(from: sender, title: "Master", min: 0, max: 100, step: 1,
                       value: Double(store.masterGain) * 100, suffix: "%", icon: "speaker.wave.2") { [weak self] v in
                guard let self else { return }
                self.setChip(self.masterChip, value: v, suffix: "%", icon: "speaker.wave.2")
                self.delegate?.transportSetMaster(Float(v / 100))
            }
        } else {
            // Length chip — show 1 Bar / 2 Bars picker
            guard let parentVC = parentViewController else { return }
            let sheet = UIAlertController(title: "Pattern Length", message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "16 steps / 1 bar", style: store.patternLength == 16 ? .destructive : .default) { [weak self] _ in
                self?.delegate?.transportDidRequestPatternLength(16)
            })
            sheet.addAction(UIAlertAction(title: "32 steps / 2 bars", style: store.patternLength == 32 ? .destructive : .default) { [weak self] _ in
                self?.delegate?.transportDidRequestPatternLength(32)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            sheet.popoverPresentationController?.sourceView = sender
            parentVC.present(sheet, animated: true)
        }
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

        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = Theme.accent.withAlphaComponent(0.75).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iconView.tintColor = Theme.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(iconView)

        titleLabel.text = controlTitle
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = Theme.accent
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
        slider.minimumTrackTintColor = Theme.accent
        slider.maximumTrackTintColor = Theme.border
        slider.thumbTintColor = Theme.text
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

// MARK: - Responder helper

private extension UIResponder {
    var parentViewController: UIViewController? {
        next as? UIViewController ?? next?.parentViewController
    }
}
