import UIKit

final class ActionsViewController: UIViewController {

    var onSaveMix: (() -> Void)?
    var onClearBar: ((Int) -> Void)?
    var onExportWAV: (() -> Void)?
    var onExportM4A: (() -> Void)?
    var onCopyBar1ToBar2: (() -> Void)?

    /// Set before presenting: used to label "Clear Bar N" and to scope the clear action.
    var patternLength: Int = 16
    var currentBar: Int = 0

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
        let preferred = panel.widthAnchor.constraint(equalToConstant: 420)
        preferred.priority = .defaultHigh

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            preferred,
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 16),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -16),
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
        let twoBarPattern = patternLength == 32

        // Column 1 — bar actions
        let copyBtn = actionButton("Copy 1 → 2", icon: "doc.on.doc")
        copyBtn.isEnabled = twoBarPattern
        copyBtn.alpha = twoBarPattern ? 1.0 : 0.35
        copyBtn.addTarget(self, action: #selector(copyBar1ToBar2Tapped), for: .touchUpInside)
        let clearBar1Btn = actionButton("Clear Bar 1", icon: "trash.fill", isDestructive: true)
        clearBar1Btn.tag = 0
        clearBar1Btn.addTarget(self, action: #selector(clearBarTapped), for: .touchUpInside)
        let clearBar2Btn = actionButton("Clear Bar 2", icon: "trash.fill", isDestructive: true)
        clearBar2Btn.tag = 1
        clearBar2Btn.isEnabled = twoBarPattern
        clearBar2Btn.alpha = twoBarPattern ? 1.0 : 0.35
        clearBar2Btn.addTarget(self, action: #selector(clearBarTapped), for: .touchUpInside)

        // Column 2 — output actions
        let saveBtn = actionButton("Save Mix", icon: "plus.circle")
        saveBtn.addTarget(self, action: #selector(saveMixTapped), for: .touchUpInside)
        let wavBtn = actionButton("Export WAV", icon: "square.and.arrow.up")
        wavBtn.addTarget(self, action: #selector(exportWAVTapped), for: .touchUpInside)
        let m4aBtn = actionButton("Export M4A", icon: "square.and.arrow.up")
        m4aBtn.addTarget(self, action: #selector(exportM4ATapped), for: .touchUpInside)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(row([copyBtn, saveBtn]))
        stack.addArrangedSubview(row([clearBar1Btn, wavBtn]))
        stack.addArrangedSubview(row([clearBar2Btn, m4aBtn]))
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

    // MARK: - Actions

    @objc private func saveMixTapped() {
        dismiss(animated: true) { [weak self] in self?.onSaveMix?() }
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

    @objc private func copyBar1ToBar2Tapped() {
        dismiss(animated: true) { [weak self] in self?.onCopyBar1ToBar2?() }
    }

    @objc private func dismissSelf() { dismiss(animated: true) }
}
