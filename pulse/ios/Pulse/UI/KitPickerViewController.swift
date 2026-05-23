import UIKit

final class KitPickerViewController: UIViewController {

    var onSelect: ((SampleKit) -> Void)?

    private let currentKitId: String
    private let panel = UIView()

    init(currentKitId: String) {
        self.currentKitId = currentKitId
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
        bg.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(bg)

        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = Theme.border.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let titleLabel = UILabel()
        titleLabel.text = "Sound Kit"
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

        let leftCol = UIStackView()
        leftCol.axis = .vertical
        leftCol.spacing = 6

        let rightCol = UIStackView()
        rightCol.axis = .vertical
        rightCol.spacing = 6

        for (i, kit) in SampleKits.all.enumerated() {
            let btn = makeKitButton(kit: kit, index: i)
            (i < 7 ? leftCol : rightCol).addArrangedSubview(btn)
        }

        let hStack = UIStackView(arrangedSubviews: [leftCol, rightCol])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(hStack)

        let safe = view.safeAreaLayoutGuide
        let preferred = panel.widthAnchor.constraint(equalToConstant: 520)
        preferred.priority = .defaultHigh

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            preferred,
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 16),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            hStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            hStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            hStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    private func makeKitButton(kit: SampleKit, index: Int) -> UIButton {
        let selected = kit.id == currentKitId
        var cfg = UIButton.Configuration.plain()
        cfg.title = kit.name
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        cfg.background.cornerRadius = 8
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
            return out
        }
        cfg.baseForegroundColor = selected ? UIColor(white: 0.1, alpha: 1) : Theme.text
        cfg.background.backgroundColor = selected ? ColorTheme.current.primaryColor : Theme.backgroundElevated
        if !selected {
            cfg.background.strokeColor = Theme.border
            cfg.background.strokeWidth = 1
        }
        let btn = UIButton(configuration: cfg)
        btn.tag = index
        btn.addTarget(self, action: #selector(kitTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    @objc private func kitTapped(_ sender: UIButton) {
        let kit = SampleKits.all[sender.tag]
        dismiss(animated: true) { [weak self] in self?.onSelect?(kit) }
    }
}
