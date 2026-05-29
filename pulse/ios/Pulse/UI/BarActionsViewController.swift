import UIKit

final class BarActionsViewController: UIViewController {

    var onClearBar: (() -> Void)?
    var onRandomizeBar: ((RandomizeIntensity) -> Void)?
    var onHumanizeBar: (() -> Void)?
    var onDuplicateToBar2: (() -> Void)?
    var onGenerateBar2Variation: (() -> Void)?
    var onCopyBar1Here: (() -> Void)?
    var onAccentBar: ((AccentPattern) -> Void)?
    var onClearBarAccents: (() -> Void)?

    private let barIndex: Int
    private let panel = UIView()

    init(barIndex: Int) {
        self.barIndex = barIndex
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
        titleLabel.text = "Bar \(barIndex + 1) Actions"
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

        let clearBtn = actionButton("Clear Bar", icon: "trash.fill", isDestructive: true)
        clearBtn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        let randomizeBtn = actionButton("Randomize Bar", icon: "dice")
        randomizeBtn.addTarget(self, action: #selector(randomizeTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([clearBtn, randomizeBtn]))

        let humanizeBtn = actionButton("Mutate Bar", icon: "wand.and.stars")
        humanizeBtn.addTarget(self, action: #selector(humanizeTapped), for: .touchUpInside)

        if barIndex == 0 {
            let dupBtn = actionButton("Duplicate to Bar 2", icon: "doc.on.doc")
            dupBtn.addTarget(self, action: #selector(duplicateTapped), for: .touchUpInside)
            stack.addArrangedSubview(row([humanizeBtn, dupBtn]))

            let variationBtn = actionButton("Vary to Bar 2", icon: "sparkles")
            variationBtn.addTarget(self, action: #selector(variationTapped), for: .touchUpInside)
            stack.addArrangedSubview(row([variationBtn]))
        } else {
            let copyBtn = actionButton("Copy Bar 1 Here", icon: "arrow.down.doc")
            copyBtn.addTarget(self, action: #selector(copyBar1Tapped), for: .touchUpInside)
            stack.addArrangedSubview(row([humanizeBtn, copyBtn]))
        }

        let downbeatBtn = actionButton("Accent Downbeats", icon: "arrow.down.to.line")
        downbeatBtn.tag = 0
        downbeatBtn.addTarget(self, action: #selector(accentTapped(_:)), for: .touchUpInside)
        let upbeatBtn = actionButton("Accent Upbeats", icon: "arrow.up.to.line")
        upbeatBtn.tag = 1
        upbeatBtn.addTarget(self, action: #selector(accentTapped(_:)), for: .touchUpInside)
        stack.addArrangedSubview(row([downbeatBtn, upbeatBtn]))

        let clearAccentsBtn = actionButton("Clear Accents", icon: "bolt.slash")
        clearAccentsBtn.addTarget(self, action: #selector(clearAccentsTapped), for: .touchUpInside)
        stack.addArrangedSubview(row([clearAccentsBtn]))

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

    @objc private func clearTapped() {
        let alert = UIAlertController(
            title: "Clear Bar \(barIndex + 1)?",
            message: "This removes all steps from Bar \(barIndex + 1).",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear Bar", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) { self?.onClearBar?() }
        })
        present(alert, animated: true)
    }

    @objc private func randomizeTapped() {
        let sheet = UIAlertController(title: "Randomize Bar \(barIndex + 1)", message: nil, preferredStyle: .actionSheet)
        for intensity in RandomizeIntensity.allCases {
            sheet.addAction(UIAlertAction(title: intensity.title, style: .default) { [weak self] _ in
                self?.dismiss(animated: true) { self?.onRandomizeBar?(intensity) }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = view.bounds
        present(sheet, animated: true)
    }

    @objc private func humanizeTapped() {
        dismiss(animated: true) { [weak self] in self?.onHumanizeBar?() }
    }

    @objc private func duplicateTapped() {
        dismiss(animated: true) { [weak self] in self?.onDuplicateToBar2?() }
    }

    @objc private func variationTapped() {
        dismiss(animated: true) { [weak self] in self?.onGenerateBar2Variation?() }
    }

    @objc private func copyBar1Tapped() {
        dismiss(animated: true) { [weak self] in self?.onCopyBar1Here?() }
    }

    @objc private func accentTapped(_ sender: UIButton) {
        let pattern: AccentPattern = sender.tag == 0 ? .downbeat : .upbeat
        dismiss(animated: true) { [weak self] in self?.onAccentBar?(pattern) }
    }

    @objc private func clearAccentsTapped() {
        dismiss(animated: true) { [weak self] in self?.onClearBarAccents?() }
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}
