import UIKit

final class ActionsViewController: UIViewController {

    var onSaveMix: (() -> Void)?
    var onUndo: (() -> Void)?
    var onHumanizeGroove: (() -> Void)?
    var onRandomizeGroove: (() -> Void)?
    var onClearBar: ((Int) -> Void)?
    var onExportWAV: (() -> Void)?
    var onExportM4A: (() -> Void)?
    var onSettings: (() -> Void)?
    var onCopyBar1ToBar2: (() -> Void)?

    /// Set before presenting: used to label "Clear Bar N" and to scope the clear action.
    var patternLength: Int = 16
    var currentBar: Int = 0
    var canUndo: Bool = false

    private let panel = UIView()

    init() {
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
        titleLabel.text = "Actions"
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
        let preferred = panel.widthAnchor.constraint(equalToConstant: 480)
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
        stack.spacing = 8

        // Row 1: Save Mix + Undo  (mix group — blue-gray)
        let saveMixBtn = actionButton("Save Mix", icon: "plus.circle", group: .mix)
        saveMixBtn.addTarget(self, action: #selector(saveMixTapped), for: .touchUpInside)
        let undoBtn = actionButton("Undo", icon: "arrow.uturn.backward", group: .mix, isDimmed: !canUndo)
        undoBtn.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        undoBtn.isEnabled = canUndo
        stack.addArrangedSubview(row([saveMixBtn, undoBtn]))

        // Row 2: Humanize + Randomize  (creative group — purple)
        let humanizeBtn = actionButton("Humanize Groove", icon: "wand.and.stars", group: .creative)
        humanizeBtn.addTarget(self, action: #selector(humanizeTapped), for: .touchUpInside)
        let randomizeBtn = actionButton("Randomize Groove", icon: "dice", group: .creative)
        randomizeBtn.addTarget(self, action: #selector(randomizeTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([humanizeBtn, randomizeBtn]))

        // Row 3: Clear Bar 1 + Clear Bar 2  (clear group — red/pink)
        let bar2Disabled = patternLength != 32
        let clearBar1Btn = actionButton("Clear Bar 1", icon: "trash", group: .clear)
        clearBar1Btn.tag = 0
        clearBar1Btn.addTarget(self, action: #selector(clearBarTapped), for: .touchUpInside)
        let clearBar2Btn = actionButton("Clear Bar 2", icon: "trash", group: .clear, isDimmed: bar2Disabled)
        clearBar2Btn.isEnabled = !bar2Disabled
        clearBar2Btn.tag = 1
        clearBar2Btn.addTarget(self, action: #selector(clearBarTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([clearBar1Btn, clearBar2Btn]))

        // Row 4: Export WAV + Export M4A  (export group — teal)
        let wavBtn = actionButton("Export WAV", icon: "square.and.arrow.up", group: .export)
        wavBtn.addTarget(self, action: #selector(exportWAVTapped), for: .touchUpInside)
        let m4aBtn = actionButton("Export M4A", icon: "square.and.arrow.up", group: .export)
        m4aBtn.addTarget(self, action: #selector(exportM4ATapped), for: .touchUpInside)
        stack.addArrangedSubview(row([wavBtn, m4aBtn]))

        // Row 5: Settings + Copy Bar 1 to Bar 2
        let settingsBtn = actionButton("Settings", icon: "gear", group: .settings)
        settingsBtn.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        let copyDisabled = patternLength != 32
        let copyBtn = actionButton("Copy Bar 1 to Bar 2", icon: "doc.on.doc", group: .mix, isDimmed: copyDisabled)
        copyBtn.isEnabled = !copyDisabled
        copyBtn.addTarget(self, action: #selector(copyBar1ToBar2Tapped), for: .touchUpInside)
        stack.addArrangedSubview(row([copyBtn, settingsBtn]))

        return stack
    }

    // MARK: - Button factory

    private enum ButtonGroup {
        case mix, creative, clear, export, neutral, settings

        /// Low-opacity tinted background — dark base stays visible.
        var bgColor: UIColor {
            switch self {
            case .mix:      return UIColor(red: 0.24, green: 0.35, blue: 0.55, alpha: 0.14)
            case .creative: return UIColor(red: 0.39, green: 0.27, blue: 0.71, alpha: 0.14)
            case .clear:    return UIColor(red: 0.71, green: 0.20, blue: 0.22, alpha: 0.11)
            case .export:   return UIColor(red: 0.12, green: 0.61, blue: 0.51, alpha: 0.13)
            case .neutral:  return Theme.backgroundElevated
            case .settings: return UIColor(red: 0.65, green: 0.38, blue: 0.10, alpha: 0.14)
            }
        }

        /// Subtle colored stroke — clearly tinted but not neon.
        var borderColor: UIColor {
            switch self {
            case .mix:      return UIColor(red: 0.31, green: 0.47, blue: 0.75, alpha: 0.30)
            case .creative: return UIColor(red: 0.55, green: 0.39, blue: 0.86, alpha: 0.30)
            case .clear:    return UIColor(red: 0.86, green: 0.31, blue: 0.33, alpha: 0.28)
            case .export:   return UIColor(red: 0.16, green: 0.75, blue: 0.63, alpha: 0.30)
            case .neutral:  return Theme.border
            case .settings: return UIColor(red: 0.85, green: 0.52, blue: 0.18, alpha: 0.30)
            }
        }

        /// Icon tint — stronger color to act as the visual anchor for each group.
        var iconColor: UIColor {
            switch self {
            case .mix:      return UIColor(red: 0.49, green: 0.72, blue: 0.96, alpha: 1.0)
            case .creative: return UIColor(red: 0.72, green: 0.62, blue: 1.00, alpha: 1.0)
            case .clear:    return UIColor(red: 1.00, green: 0.49, blue: 0.50, alpha: 1.0)
            case .export:   return UIColor(red: 0.20, green: 0.85, blue: 0.71, alpha: 1.0)
            case .neutral:  return Theme.textDim
            case .settings: return UIColor(red: 1.00, green: 0.68, blue: 0.28, alpha: 1.0)
            }
        }
    }

    private func actionButton(_ title: String, icon: String,
                              group: ButtonGroup = .neutral, isDimmed: Bool = false) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        cfg.imagePlacement = .leading
        cfg.imagePadding = 8
        cfg.background.backgroundColor = group.bgColor
        cfg.background.strokeColor = group.borderColor
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 8
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        // Icon uses the group color; title is forced to Theme.text via the transformer
        cfg.baseForegroundColor = group.iconColor
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13, weight: .medium)
            out.foregroundColor = Theme.text
            return out
        }
        let btn = UIButton(configuration: cfg)
        btn.alpha = isDimmed ? 0.35 : 1.0
        return btn
    }

    private func row(_ buttons: [UIButton]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    // MARK: - Actions

    @objc private func saveMixTapped() {
        dismiss(animated: true) { [weak self] in self?.onSaveMix?() }
    }

    @objc private func undoTapped() {
        dismiss(animated: true) { [weak self] in self?.onUndo?() }
    }

    @objc private func humanizeTapped() {
        dismiss(animated: true) { [weak self] in self?.onHumanizeGroove?() }
    }

    @objc private func randomizeTapped() {
        let alert = UIAlertController(
            title: "Randomize Groove?",
            message: "This replaces all track patterns with new musical sequences.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Randomize", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) { self?.onRandomizeGroove?() }
        })
        present(alert, animated: true)
    }

    @objc private func clearBarTapped(_ sender: UIButton) {
        let barName = "Bar \(sender.tag + 1)"
        let alert = UIAlertController(
            title: "Clear \(barName)?",
            message: "This removes all steps from \(barName).",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear \(barName)", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) { self?.onClearBar?(sender.tag) }
        })
        present(alert, animated: true)
    }

    @objc private func exportWAVTapped() {
        dismiss(animated: true) { [weak self] in self?.onExportWAV?() }
    }

    @objc private func exportM4ATapped() {
        dismiss(animated: true) { [weak self] in self?.onExportM4A?() }
    }

    @objc private func settingsTapped() {
        dismiss(animated: true) { [weak self] in self?.onSettings?() }
    }

    @objc private func copyBar1ToBar2Tapped() {
        dismiss(animated: true) { [weak self] in self?.onCopyBar1ToBar2?() }
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}
