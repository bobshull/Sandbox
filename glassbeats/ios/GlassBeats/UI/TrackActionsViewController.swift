import UIKit

final class TrackActionsViewController: UIViewController {

    var onPreviewSound: (() -> Void)?
    var onClearTrack: (() -> Void)?
    var onShiftLeft: (() -> Void)?
    var onShiftRight: (() -> Void)?
    var onRandomizeTrack: ((RandomizeIntensity) -> Void)?
    var onClearTrackAccents: (() -> Void)?

    /// Set before presenting: Clear Accents is only enabled when the track has accents.
    var trackHasAccents: Bool = false

    private let track: Track
    private let panel = UIView()

    init(track: Track) {
        self.track = track
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

        let swatchView = UIView()
        swatchView.backgroundColor = ColorTheme.current.color(for: track.id)
        swatchView.layer.cornerRadius = 5
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(swatchView)

        let titleLabel = UILabel()
        titleLabel.text = track.name
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

        let hintLabel = UILabel()
        hintLabel.text = "Long-press a step to show more options."
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = Theme.textFaint
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(hintLabel)

        let safe = view.safeAreaLayoutGuide
        let preferred = panel.widthAnchor.constraint(equalToConstant: 400)
        preferred.priority = .defaultHigh

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            preferred,
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 20),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -20),
            panel.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: 12),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -12),

            swatchView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            swatchView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            swatchView.widthAnchor.constraint(equalToConstant: 10),
            swatchView.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: swatchView.trailingAnchor, constant: 8),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            contentStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),

            hintLabel.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            hintLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])
    }

    private func makeContentStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let previewBtn = actionButton("Preview Sound", icon: "speaker.wave.2.fill")
        previewBtn.addTarget(self, action: #selector(previewTapped), for: .touchUpInside)
        let randomizeBtn = actionButton("Randomize Track", icon: "dice")
        randomizeBtn.addTarget(self, action: #selector(randomizeTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([previewBtn, randomizeBtn]))

        let shiftLeftBtn = actionButton("Shift Left", icon: "arrow.left")
        shiftLeftBtn.addTarget(self, action: #selector(shiftLeftTapped), for: .touchUpInside)
        let shiftRightBtn = actionButton("Shift Right", icon: "arrow.right")
        shiftRightBtn.addTarget(self, action: #selector(shiftRightTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([shiftLeftBtn, shiftRightBtn]))

        let clearAccentsBtn = actionButton("Clear Accents", icon: "bolt.slash", isDestructive: true)
        clearAccentsBtn.addTarget(self, action: #selector(clearAccentsTapped), for: .touchUpInside)
        clearAccentsBtn.isEnabled = trackHasAccents
        clearAccentsBtn.alpha = trackHasAccents ? 1.0 : 0.35
        let clearBtn = actionButton("Clear Track", icon: "trash.fill", isDestructive: true)
        clearBtn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([clearAccentsBtn, clearBtn]))

        return stack
    }

    private func actionButton(_ title: String, icon: String, isDestructive: Bool = false) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        cfg.imagePlacement = .leading
        cfg.imagePadding = 8
        cfg.background.backgroundColor = Theme.backgroundElevated
        cfg.background.strokeColor = isDestructive ? Theme.danger.withAlphaComponent(0.5) : Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 8
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13, weight: .medium)
            return out
        }
        cfg.baseForegroundColor = isDestructive ? Theme.danger : Theme.text
        return UIButton(configuration: cfg)
    }

    private func row(_ buttons: [UIButton]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    @objc private func previewTapped() {
        onPreviewSound?()
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(
            title: "Clear \(track.name)?",
            message: "This removes all steps for \(track.name) in the current pattern.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear Track", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) { self?.onClearTrack?() }
        })
        present(alert, animated: true)
    }

    @objc private func shiftLeftTapped() {
        dismiss(animated: true) { [weak self] in self?.onShiftLeft?() }
    }

    @objc private func shiftRightTapped() {
        dismiss(animated: true) { [weak self] in self?.onShiftRight?() }
    }

    @objc private func randomizeTapped() {
        let sheet = UIAlertController(title: "Randomize \(track.name)", message: nil, preferredStyle: .actionSheet)
        for intensity in RandomizeIntensity.allCases {
            sheet.addAction(UIAlertAction(title: intensity.title, style: .default) { [weak self] _ in
                self?.dismiss(animated: true) { self?.onRandomizeTrack?(intensity) }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = view.bounds
        present(sheet, animated: true)
    }

    @objc private func clearAccentsTapped() {
        dismiss(animated: true) { [weak self] in self?.onClearTrackAccents?() }
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}
