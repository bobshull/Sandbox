import UIKit

/// Compact editor for a single active step, opened by long-pressing a cell.
/// All tracks expose Accent; melodic tracks (bass/pluck/pad) also expose Pitch.
/// Changes apply immediately; the panel stays up for quick tweaking.
final class StepOptionsViewController: UIViewController {

    var onSetAccent: ((Bool) -> Void)?
    var onSetPitch: ((Int) -> Void)?

    private let track: Track
    private let step: Int
    private var isAccented: Bool
    private var pitch: Int
    private let panel = UIView()

    private var accentButtons: [UIButton] = []
    private var pitchButtons: [UIButton] = []

    init(track: Track, step: Int, isAccented: Bool, pitch: Int) {
        self.track = track
        self.step = step
        self.isAccented = isAccented
        self.pitch = pitch
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let bgTap = UIButton(type: .custom)
        bgTap.frame = view.bounds
        bgTap.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bgTap.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(bgTap)

        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = Theme.border.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let titleLabel = UILabel()
        titleLabel.text = "\(track.name) · Step \(step + 1)"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = Theme.text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textFaint
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(closeButton)

        let contentStack = makeContentStack()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(contentStack)

        let safe = view.safeAreaLayoutGuide
        let preferred = panel.widthAnchor.constraint(equalToConstant: 340)
        preferred.priority = .defaultHigh

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            preferred,
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 20),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -20),
            panel.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: 12),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            contentStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    private func makeContentStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(sectionLabel("Accent"))
        accentButtons = [segmentButton("Off", tag: 0, action: #selector(accentTapped(_:))),
                         segmentButton("On",  tag: 1, action: #selector(accentTapped(_:)))]
        stack.addArrangedSubview(segmentRow(accentButtons))

        if let options = StepPitch.options(for: track.voice) {
            stack.addArrangedSubview(sectionLabel("Pitch"))
            pitchButtons = options.map {
                segmentButton($0.label, tag: $0.semitones, action: #selector(pitchTapped(_:)))
            }
            stack.addArrangedSubview(segmentRow(pitchButtons))
        }

        syncSelection()
        return stack
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = Theme.textFaint
        return label
    }

    private func segmentButton(_ title: String, tag: Int, action: Selector) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 8
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13, weight: .medium)
            return out
        }
        let button = UIButton(configuration: cfg)
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func segmentRow(_ buttons: [UIButton]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    private func syncSelection() {
        let primary = ColorTheme.current.primaryColor
        func apply(_ button: UIButton, selected: Bool) {
            var cfg = button.configuration ?? .plain()
            cfg.background.backgroundColor = selected ? primary.withAlphaComponent(0.22) : Theme.backgroundElevated
            cfg.background.strokeColor     = selected ? primary : Theme.border
            cfg.baseForegroundColor        = selected ? primary : Theme.text
            button.configuration = cfg
        }
        for button in accentButtons { apply(button, selected: (button.tag == 1) == isAccented) }
        for button in pitchButtons { apply(button, selected: button.tag == pitch) }
    }

    @objc private func accentTapped(_ sender: UIButton) {
        let accented = sender.tag == 1
        guard accented != isAccented else { return }
        isAccented = accented
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        syncSelection()
        onSetAccent?(accented)
    }

    @objc private func pitchTapped(_ sender: UIButton) {
        guard sender.tag != pitch else { return }
        pitch = sender.tag
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        syncSelection()
        onSetPitch?(sender.tag)
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}
