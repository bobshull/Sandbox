import UIKit

// MARK: - Kit presentation metadata

private struct KitMeta {
    let icon: String
    let accent: UIColor

    static let lookup: [String: KitMeta] = [
        "studio":      .init(icon: "waveform",           accent: .init(r: 122, g: 143, b: 166)),
        "dusty-tape":  .init(icon: "rectangle.stack",    accent: .init(r: 176, g: 137, b: 104)),
        "boom-bap":    .init(icon: "speaker.wave.2",     accent: .init(r: 245, g: 158, b: 11)),
        "808":         .init(icon: "waveform.path.ecg",  accent: .init(r: 168, g: 85,  b: 247)),
        "jazz":        .init(icon: "music.mic",          accent: .init(r: 212, g: 167, b: 44)),
        "rainy-night": .init(icon: "cloud.rain",         accent: .init(r: 59,  g: 130, b: 246)),
        "music-box":   .init(icon: "sparkle",            accent: .init(r: 249, g: 168, b: 212)),
        "wind-chimes": .init(icon: "wind",               accent: .init(r: 103, g: 232, b: 249)),
        "marimba":     .init(icon: "music.note",         accent: .init(r: 217, g: 119, b: 6)),
        "arcade":      .init(icon: "gamecontroller",     accent: .init(r: 34,  g: 197, b: 94)),
        "glass":       .init(icon: "diamond",            accent: .init(r: 165, g: 243, b: 252)),
        "toy-piano":   .init(icon: "pianokeys",          accent: .init(r: 196, g: 181, b: 253)),
        "jungle":      .init(icon: "leaf",               accent: .init(r: 22,  g: 163, b: 74)),
        "space":       .init(icon: "sparkles",           accent: .init(r: 99,  g: 102, b: 241)),
    ]
}

private extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

// MARK: - View controller

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
        let meta = KitMeta.lookup[kit.id] ?? KitMeta(icon: "music.note", accent: UIColor(white: 0.5, alpha: 1))
        let accent = meta.accent

        var cfg = UIButton.Configuration.plain()
        cfg.title = kit.name
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        cfg.background.cornerRadius = 8
        cfg.imagePlacement = .leading
        cfg.imagePadding = 7
        cfg.titleLineBreakMode = .byTruncatingTail

        let symCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        cfg.image = UIImage(systemName: meta.icon, withConfiguration: symCfg)

        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13.5, weight: selected ? .semibold : .regular)
            return out
        }

        cfg.background.strokeColor = Theme.border
        cfg.background.strokeWidth = 1.5

        if selected {
            cfg.background.backgroundColor = ColorTheme.current.primaryColor
            cfg.baseForegroundColor = UIColor(white: 0.1, alpha: 1)
            cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in UIColor(white: 0.1, alpha: 1) }
        } else {
            cfg.background.backgroundColor = Theme.backgroundElevated
            cfg.baseForegroundColor = Theme.textDim
            cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in accent.withAlphaComponent(0.70) }
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
