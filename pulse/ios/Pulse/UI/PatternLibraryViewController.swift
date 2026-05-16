import UIKit

protocol PatternLibraryDelegate: AnyObject {
    func patternLibraryDidPick(_ pattern: Pattern)
}

final class PatternLibraryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: PatternLibraryDelegate?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private typealias Category = (title: String, patterns: [Pattern])
    private static let categoryOrder: [(String, [String])] = [
        ("Electronic",     ["floor-filler", "dubstep", "house-pulse", "breakbeat"]),
        ("Hip-Hop",        ["boom-bap", "half-time"]),
        ("Chill / Lo-Fi",  ["lofi-shuffle", "chillhop", "tape-deck"]),
        ("Minimal",        ["minimal", "empty"]),
    ]
    private var categories: [Category] = []
    private var userPatterns: [Pattern] = []
    private let currentName: String
    private let currentKitId: String
    init(currentName: String, currentKitId: String = "studio") {
        self.currentName = currentName
        self.currentKitId = currentKitId
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        // Now-playing pill
        let nowPill = UIButton(type: .custom)
        var pillCfg = UIButton.Configuration.plain()
        pillCfg.image = UIImage(systemName: "waveform",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        pillCfg.imagePadding = 6
        pillCfg.title = currentName
        pillCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        pillCfg.baseForegroundColor = Theme.text
        pillCfg.background.backgroundColor = Theme.backgroundElevated
        pillCfg.background.strokeColor = Theme.accent.withAlphaComponent(0.55)
        pillCfg.background.strokeWidth = 1.5
        pillCfg.background.cornerRadius = 16
        pillCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
        nowPill.configuration = pillCfg
        nowPill.isUserInteractionEnabled = false
        nowPill.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(nowPill)

        // iCloud sync icon — green checkmark when signed in, dim cloud when not
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        let cloudSymbol = iCloudAvailable ? "checkmark.icloud.fill" : "icloud"
        let cloudIcon = UIImageView(image: UIImage(systemName: cloudSymbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        cloudIcon.tintColor = iCloudAvailable
            ? UIColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1)
            : Theme.textFaint
        cloudIcon.contentMode = .scaleAspectFit
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(cloudIcon)

        // Action buttons
        let closeButton = UIButton(type: .system)
        configureActionButton(closeButton, label: "Close", primary: false, action: #selector(closeTapped))
        let buttons = UIStackView(arrangedSubviews: [closeButton])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(buttons)

        // Table
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(MixCell.self, forCellReuseIdentifier: MixCell.id)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: tableView.layoutMarginsGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: tableView.layoutMarginsGuide.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 34),

            nowPill.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            nowPill.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            nowPill.trailingAnchor.constraint(lessThanOrEqualTo: cloudIcon.leadingAnchor, constant: -8),

            cloudIcon.leadingAnchor.constraint(equalTo: nowPill.trailingAnchor, constant: 8),
            cloudIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            cloudIcon.widthAnchor.constraint(equalToConstant: 20),
            cloudIcon.heightAnchor.constraint(equalToConstant: 20),
            cloudIcon.trailingAnchor.constraint(lessThanOrEqualTo: buttons.leadingAnchor, constant: -12),

            buttons.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            buttons.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            buttons.heightAnchor.constraint(equalToConstant: 34),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        reload()
    }

    func reload() {
        let lookup = Dictionary(uniqueKeysWithValues: Presets.all.map { ($0.id, $0) })
        categories = PatternLibraryViewController.categoryOrder.compactMap { title, ids in
            let patterns = ids.compactMap { lookup[$0] }
            return patterns.isEmpty ? nil : (title, patterns)
        }
        userPatterns = PatternStore.userPatterns()
        tableView.reloadData()
    }

    private func configureActionButton(_ button: UIButton, label: String, primary: Bool, action: Selector) {
        var cfg = UIButton.Configuration.plain()
        cfg.title = label
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        cfg.background.cornerRadius = 6
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        if primary {
            cfg.baseForegroundColor = UIColor(white: 0.1, alpha: 1)
            cfg.background.backgroundColor = Theme.accent
        } else {
            cfg.baseForegroundColor = Theme.text
            cfg.background.backgroundColor = Theme.backgroundElevated2
            cfg.background.strokeColor = Theme.border
            cfg.background.strokeWidth = 1
        }
        button.configuration = cfg
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - Table

    private var userSection: Int { categories.count }

    func numberOfSections(in tableView: UITableView) -> Int { categories.count + 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section < categories.count ? categories[section].title : "My Mixes"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section < categories.count ? categories[section].patterns.count : max(userPatterns.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MixCell.id, for: indexPath) as! MixCell
        if indexPath.section < categories.count {
            cell.configure(with: categories[indexPath.section].patterns[indexPath.row])
            cell.selectionStyle = .default
        } else if userPatterns.isEmpty {
            cell.configureEmpty()
            cell.selectionStyle = .none
        } else {
            cell.configure(with: userPatterns[indexPath.row])
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let pattern: Pattern
        if indexPath.section < categories.count {
            pattern = categories[indexPath.section].patterns[indexPath.row]
        } else {
            guard !userPatterns.isEmpty else { return }
            pattern = userPatterns[indexPath.row]
        }
        dismiss(animated: true) { [weak self] in self?.delegate?.patternLibraryDidPick(pattern) }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == userSection && !userPatterns.isEmpty
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == userSection else { return }
        PatternStore.delete(id: userPatterns[indexPath.row].id)
        reload()
    }
}

// MARK: - MixCell

final class MixCell: UITableViewCell {
    static let id = "MixCell"

    private let nameLabel = UILabel()
    private let bpmPill = PaddedLabel()
    private let swingLabel = PaddedLabel()
    private let beatGrid = BeatGridView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = Theme.backgroundElevated
        backgroundConfiguration = bg

        let sel = UIView()
        sel.backgroundColor = Theme.backgroundElevated2
        selectedBackgroundView = sel

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = Theme.text
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        bpmPill.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        bpmPill.textColor = Theme.accent
        bpmPill.backgroundColor = Theme.accent.withAlphaComponent(0.12)
        bpmPill.layer.cornerRadius = 4
        bpmPill.layer.masksToBounds = true
        bpmPill.textAlignment = .center
        bpmPill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bpmPill)

        swingLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        swingLabel.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
        swingLabel.backgroundColor = UIColor(red: 0.608, green: 0.965, blue: 1.0, alpha: 1)
        swingLabel.layer.cornerRadius = 4
        swingLabel.layer.masksToBounds = true
        swingLabel.textAlignment = .center
        swingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(swingLabel)

        // height constraints removed — PaddedLabel intrinsicContentSize handles it

        beatGrid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(beatGrid)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            bpmPill.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bpmPill.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            bpmPill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            swingLabel.leadingAnchor.constraint(equalTo: bpmPill.trailingAnchor, constant: 6),
            swingLabel.centerYAnchor.constraint(equalTo: bpmPill.centerYAnchor),

            beatGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            beatGrid.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            beatGrid.widthAnchor.constraint(equalToConstant: BeatGridView.W),
            beatGrid.heightAnchor.constraint(equalToConstant: BeatGridView.H),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with pattern: Pattern) {
        nameLabel.text = pattern.name
        nameLabel.textColor = Theme.text
        bpmPill.text = "\(Int(pattern.tempo)) BPM"
        bpmPill.isHidden = false
        swingLabel.text = "swing \(Int((pattern.swing * 100).rounded()))%"
        swingLabel.isHidden = false
        beatGrid.configure(rows: pattern.rows)
        beatGrid.isHidden = false
    }

    func configureEmpty() {
        nameLabel.text = "No mixes saved yet"
        nameLabel.textColor = Theme.textFaint
        bpmPill.isHidden = true
        swingLabel.isHidden = true
        beatGrid.isHidden = true
    }
}

// MARK: - BeatGridView

final class BeatGridView: UIView {
    static let dotSize: CGFloat = 5
    static let dotGap: CGFloat  = 2
    static let rowGap: CGFloat  = 5
    static let steps = 16
    static let trackIds  = ["kick", "snare", "hat"]
    static let colors: [(CGFloat, CGFloat, CGFloat)] = [
        (1.00,  0.478, 0.349),  // kick  #ff7a59
        (1.00,  0.820, 0.400),  // snare #ffd166
        (0.608, 0.965, 1.00 ),  // hat   #9bf6ff
    ]
    static let W = CGFloat(steps) * dotSize + CGFloat(steps - 1) * dotGap
    static let H = CGFloat(trackIds.count) * dotSize + CGFloat(trackIds.count - 1) * rowGap

    private var dots: [[UIView]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        for ti in 0..<BeatGridView.trackIds.count {
            var row: [UIView] = []
            for si in 0..<BeatGridView.steps {
                let dot = UIView()
                dot.layer.cornerRadius = BeatGridView.dotSize / 2
                dot.translatesAutoresizingMaskIntoConstraints = false
                addSubview(dot)
                NSLayoutConstraint.activate([
                    dot.leadingAnchor.constraint(equalTo: leadingAnchor,
                        constant: CGFloat(si) * (BeatGridView.dotSize + BeatGridView.dotGap)),
                    dot.topAnchor.constraint(equalTo: topAnchor,
                        constant: CGFloat(ti) * (BeatGridView.dotSize + BeatGridView.rowGap)),
                    dot.widthAnchor.constraint(equalToConstant: BeatGridView.dotSize),
                    dot.heightAnchor.constraint(equalToConstant: BeatGridView.dotSize),
                ])
                row.append(dot)
            }
            dots.append(row)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rows: [String: [Bool]]) {
        for (ti, trackId) in BeatGridView.trackIds.enumerated() {
            let tc = BeatGridView.colors[ti]
            let steps = rows[trackId] ?? []
            for (si, dot) in dots[ti].enumerated() {
                let on = si < steps.count && steps[si]
                dot.backgroundColor = on
                    ? UIColor(red: tc.0, green: tc.1, blue: tc.2, alpha: 1)
                    : UIColor(white: 1, alpha: 0.08)
            }
        }
    }
}

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
