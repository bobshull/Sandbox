import UIKit

protocol PatternLibraryDelegate: AnyObject {
    func patternLibraryDidPick(_ pattern: Pattern)
}

private struct PresetGroup {
    let baseId: String
    let name: String
    let oneBar: Pattern
    let twoBar: Pattern?
}

final class PatternLibraryViewController: UIViewController,
        UICollectionViewDataSource, UICollectionViewDelegate {

    weak var delegate: PatternLibraryDelegate?

    private var collectionView: UICollectionView!
    private typealias Category = (title: String, color: UIColor, groups: [PresetGroup])

    private static let presetMeta: [(String, UIColor, [String])] = [
        ("Electronic",    Theme.accent,
             ["jungle-chop", "808-memphis", "arcade-rush", "space-drift"]),
        ("Hip-Hop",       UIColor(red: 1.00, green: 0.820, blue: 0.400, alpha: 1),
             ["boom-bap-classic", "dusty-breaks", "jazz-brush"]),
        ("Chill / Lo-Fi", Theme.accent2,
             ["rainy-lofi", "marimba-groove"]),
        ("Ambient",       Theme.textDim,
             ["music-box-fantasy", "empty"]),
    ]
    private static let userColor = Theme.ok

    private var categories: [Category] = []
    private var userPatterns: [Pattern] = []
    private var selectedBarLength: [String: Int] = [:]
    private let currentName: String
    private let currentPatternId: String
    private let currentKitId: String

    init(currentName: String, currentPatternId: String, currentKitId: String = "studio") {
        self.currentName = currentName
        self.currentPatternId = currentPatternId
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

        let header = buildHeader()
        view.addSubview(header)

        let layout = Self.makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.contentInset.bottom = 24
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.register(MixCardCell.self,
            forCellWithReuseIdentifier: MixCardCell.id)
        collectionView.register(
            LibrarySectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: LibrarySectionHeader.id)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: collectionView.layoutMarginsGuide.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: collectionView.layoutMarginsGuide.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 34),
        ])

        reload()
        initSelectedBarLengths()
    }

    // MARK: - Header

    private func buildHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let nowPill = UIButton(type: .custom)
        var pillCfg = UIButton.Configuration.plain()
        pillCfg.image = UIImage(systemName: "waveform",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        pillCfg.imagePadding = 6
        pillCfg.title = currentName
        pillCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var out = a; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
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

        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        let cloudIcon = UIImageView(image: UIImage(systemName:
            iCloudAvailable ? "checkmark.icloud.fill" : "icloud",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        cloudIcon.tintColor = iCloudAvailable
            ? UIColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1) : Theme.textFaint
        cloudIcon.contentMode = .scaleAspectFit
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(cloudIcon)

        let closeBtn = UIButton(type: .system)
        var closeCfg = UIButton.Configuration.plain()
        closeCfg.title = "Close"
        closeCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        closeCfg.background.cornerRadius = 6
        closeCfg.baseForegroundColor = Theme.text
        closeCfg.background.backgroundColor = Theme.backgroundElevated2
        closeCfg.background.strokeColor = Theme.border
        closeCfg.background.strokeWidth = 1
        closeCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var out = a; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        closeBtn.configuration = closeCfg
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            nowPill.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            nowPill.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            cloudIcon.leadingAnchor.constraint(equalTo: nowPill.trailingAnchor, constant: 8),
            cloudIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            cloudIcon.widthAnchor.constraint(equalToConstant: 20),
            cloudIcon.heightAnchor.constraint(equalToConstant: 20),

            closeBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            closeBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeBtn.heightAnchor.constraint(equalToConstant: 34),
        ])

        return header
    }

    // MARK: - Layout

    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(0.5),
                                  heightDimension: .estimated(145)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .estimated(145)),
                subitems: [item, item])
            group.interItemSpacing = .fixed(10)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 10
            section.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 20, trailing: 16)

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .absolute(36))
            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top)
            sectionHeader.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [sectionHeader]
            return section
        }
    }

    // MARK: - Data

    func reload() {
        var byBase: [String: (oneBar: Pattern?, twoBar: Pattern?)] = [:]
        for p in Presets.all {
            let baseId = p.basePresetId ?? p.id
            if (p.barLength ?? 1) == 2 {
                byBase[baseId, default: (nil, nil)].twoBar = p
            } else {
                byBase[baseId, default: (nil, nil)].oneBar = p
            }
        }
        categories = Self.presetMeta.compactMap { title, color, baseIds in
            let groups: [PresetGroup] = baseIds.compactMap { baseId in
                guard let oneBar = byBase[baseId]?.oneBar else { return nil }
                return PresetGroup(baseId: baseId, name: oneBar.name,
                                   oneBar: oneBar, twoBar: byBase[baseId]?.twoBar)
            }
            return groups.isEmpty ? nil : (title, color, groups)
        }
        userPatterns = PatternStore.userPatterns()
        collectionView?.reloadData()
    }

    private func initSelectedBarLengths() {
        for category in categories {
            for group in category.groups {
                if group.twoBar?.id == currentPatternId {
                    selectedBarLength[group.baseId] = 2
                }
            }
        }
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - DataSource

    private var userSection: Int { categories.count }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        categories.count + 1
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        section < categories.count ? categories[section].groups.count : userPatterns.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MixCardCell.id, for: indexPath) as! MixCardCell

        if indexPath.section < categories.count {
            let group = categories[indexPath.section].groups[indexPath.row]
            let color = categories[indexPath.section].color
            let selLen = selectedBarLength[group.baseId] ?? 1
            let isActive = group.oneBar.id == currentPatternId
                        || group.twoBar?.id == currentPatternId
            cell.configure(with: group, selectedBarLength: selLen, color: color, isActive: isActive)
            cell.onBarLengthChanged = { [weak self] length in
                guard let self else { return }
                self.selectedBarLength[group.baseId] = length
                let pattern = length == 2 ? (group.twoBar ?? group.oneBar) : group.oneBar
                self.dismiss(animated: true) { [weak self] in
                    self?.delegate?.patternLibraryDidPick(pattern)
                }
            }
        } else {
            let pattern = userPatterns[indexPath.row]
            let wrapped = PresetGroup(baseId: pattern.id, name: pattern.name,
                                      oneBar: pattern, twoBar: nil)
            let isActive = pattern.id == currentPatternId
            cell.configure(with: wrapped, selectedBarLength: 1, color: Self.userColor, isActive: isActive)
            cell.onBarLengthChanged = nil
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: LibrarySectionHeader.id,
            for: indexPath) as! LibrarySectionHeader
        if indexPath.section < categories.count {
            v.configure(title: categories[indexPath.section].title,
                        color: categories[indexPath.section].color)
        } else {
            v.configure(title: "My Mixes", color: Self.userColor)
        }
        return v
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let pattern: Pattern
        if indexPath.section < categories.count {
            let group = categories[indexPath.section].groups[indexPath.row]
            let length = selectedBarLength[group.baseId] ?? 1
            pattern = length == 2 ? (group.twoBar ?? group.oneBar) : group.oneBar
        } else {
            guard !userPatterns.isEmpty else { return }
            pattern = userPatterns[indexPath.row]
        }
        dismiss(animated: true) { [weak self] in self?.delegate?.patternLibraryDidPick(pattern) }
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == userSection, !userPatterns.isEmpty else { return nil }
        let pattern = userPatterns[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(title: "Delete",
                                  image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { [weak self] _ in
                PatternStore.delete(id: pattern.id)
                self?.reload()
            }
            return UIMenu(title: pattern.name, children: [delete])
        }
    }
}

// MARK: - MixCardCell

final class MixCardCell: UICollectionViewCell {
    static let id = "MixCardCell"

    var onBarLengthChanged: ((Int) -> Void)?

    private let accentBar    = UIView()
    private let nameLabel    = UILabel()
    private let activeIcon   = UIImageView()
    private let beatGrid     = BeatGridView()
    private let activityBars = BeatActivityView()
    private let bpmPill      = PaddedLabel()
    private let swingPill    = PaddedLabel()
    private let kitPill      = PaddedLabel()
    private let barSelector  = UISegmentedControl(items: ["1 Bar", "2 Bars"])

    private var pillsBottomC:    NSLayoutConstraint!
    private var selectorTopC:    NSLayoutConstraint!
    private var selectorBottomC: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor    = Theme.backgroundElevated
        contentView.layer.cornerRadius = Theme.cornerMedium
        contentView.layer.masksToBounds = true

        layer.cornerRadius  = Theme.cornerMedium
        layer.masksToBounds = false
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset  = CGSize(width: 0, height: 3)
        layer.shadowRadius  = 6

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        nameLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor     = Theme.text
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        activeIcon.image = UIImage(systemName: "waveform",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        activeIcon.contentMode = .scaleAspectFit
        activeIcon.isHidden    = true
        activeIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activeIcon)

        beatGrid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(beatGrid)

        activityBars.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityBars)

        bpmPill.font               = .monospacedSystemFont(ofSize: 10, weight: .medium)
        bpmPill.textColor          = Theme.accent
        bpmPill.backgroundColor    = Theme.accent.withAlphaComponent(0.12)
        bpmPill.layer.cornerRadius = 4
        bpmPill.layer.masksToBounds = true
        bpmPill.textAlignment      = .center
        bpmPill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bpmPill)

        swingPill.font               = .monospacedSystemFont(ofSize: 10, weight: .medium)
        swingPill.textColor          = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
        swingPill.backgroundColor    = UIColor(red: 0.608, green: 0.965, blue: 1.0, alpha: 1)
        swingPill.layer.cornerRadius = 4
        swingPill.layer.masksToBounds = true
        swingPill.textAlignment      = .center
        swingPill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(swingPill)

        let kitColor = UIColor(red: 1.0, green: 0.82, blue: 0.40, alpha: 1)
        kitPill.font               = .monospacedSystemFont(ofSize: 10, weight: .medium)
        kitPill.textColor          = kitColor
        kitPill.backgroundColor    = kitColor.withAlphaComponent(0.12)
        kitPill.layer.cornerRadius = 4
        kitPill.layer.masksToBounds = true
        kitPill.textAlignment      = .center
        kitPill.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(kitPill)

        let smallFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        barSelector.setTitleTextAttributes([.font: smallFont], for: .normal)
        barSelector.setTitleTextAttributes([.font: smallFont], for: .selected)
        barSelector.addTarget(self, action: #selector(barSelectorChanged), for: .valueChanged)
        barSelector.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(barSelector)

        pillsBottomC    = bpmPill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        selectorTopC    = barSelector.topAnchor.constraint(equalTo: bpmPill.bottomAnchor, constant: 6)
        selectorBottomC = barSelector.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)

        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            nameLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: activeIcon.leadingAnchor, constant: -4),

            activeIcon.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            activeIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            activeIcon.widthAnchor.constraint(equalToConstant: 16),
            activeIcon.heightAnchor.constraint(equalToConstant: 16),

            beatGrid.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            beatGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            beatGrid.widthAnchor.constraint(equalToConstant: BeatGridView.W),
            beatGrid.heightAnchor.constraint(equalToConstant: BeatGridView.H),

            activityBars.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            activityBars.centerYAnchor.constraint(equalTo: beatGrid.centerYAnchor),
            activityBars.widthAnchor.constraint(equalToConstant: BeatActivityView.W),
            activityBars.heightAnchor.constraint(equalToConstant: BeatActivityView.H),

            bpmPill.topAnchor.constraint(equalTo: beatGrid.bottomAnchor, constant: 10),
            bpmPill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),

            swingPill.leadingAnchor.constraint(equalTo: bpmPill.trailingAnchor, constant: 6),
            swingPill.centerYAnchor.constraint(equalTo: bpmPill.centerYAnchor),

            kitPill.leadingAnchor.constraint(equalTo: swingPill.trailingAnchor, constant: 6),
            kitPill.centerYAnchor.constraint(equalTo: bpmPill.centerYAnchor),

            barSelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            barSelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            pillsBottomC,
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        onBarLengthChanged = nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12, delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
                self.contentView.alpha = self.isHighlighted ? 0.75 : 1.0
            }
        }
    }

    fileprivate func configure(with group: PresetGroup, selectedBarLength: Int, color: UIColor, isActive: Bool) {
        nameLabel.text = group.name
        bpmPill.text   = "\(Int(group.oneBar.tempo)) BPM"
        swingPill.text = "swing \(Int((group.oneBar.swing * 100).rounded()))%"
        kitPill.text   = SampleKits.find(group.oneBar.kitId ?? "studio").name
        accentBar.backgroundColor = color.withAlphaComponent(0.78)

        let displayPattern = selectedBarLength == 2 ? (group.twoBar ?? group.oneBar) : group.oneBar
        beatGrid.configure(rows: displayPattern.rows)
        activityBars.configure(rows: displayPattern.rows, color: color)

        if let _ = group.twoBar {
            barSelector.isHidden = false
            barSelector.selectedSegmentIndex = selectedBarLength == 2 ? 1 : 0
            barSelector.selectedSegmentTintColor = color.withAlphaComponent(0.75)

            if pillsBottomC.isActive    { pillsBottomC.isActive    = false }
            if !selectorTopC.isActive   { selectorTopC.isActive    = true  }
            if !selectorBottomC.isActive { selectorBottomC.isActive = true  }
        } else {
            barSelector.isHidden = true

            if !pillsBottomC.isActive   { pillsBottomC.isActive    = true  }
            if selectorTopC.isActive    { selectorTopC.isActive    = false }
            if selectorBottomC.isActive { selectorBottomC.isActive = false }
        }

        activeIcon.isHidden  = !isActive
        activeIcon.tintColor = color

        if isActive {
            contentView.backgroundColor   = Theme.backgroundElevated2
            contentView.layer.borderWidth = 1.5
            contentView.layer.borderColor = color.withAlphaComponent(0.75).cgColor
            layer.shadowColor             = color.cgColor
            layer.shadowOpacity           = 0.35
            layer.shadowRadius            = 12
        } else {
            contentView.backgroundColor   = Theme.backgroundElevated
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = Theme.border.cgColor
            layer.shadowColor             = UIColor.black.cgColor
            layer.shadowOpacity           = 0.28
            layer.shadowRadius            = 6
        }
    }

    @objc private func barSelectorChanged(_ sender: UISegmentedControl) {
        let length = sender.selectedSegmentIndex == 1 ? 2 : 1
        onBarLengthChanged?(length)
    }
}

// MARK: - Section header

final class LibrarySectionHeader: UICollectionReusableView {
    static let id = "LibrarySectionHeader"

    private let pill  = UIView()
    private let dot   = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.background

        pill.backgroundColor    = Theme.backgroundElevated
        pill.layer.cornerRadius = 10
        pill.layer.borderWidth  = 1
        pill.layer.borderColor  = Theme.border.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(dot)

        label.font      = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = Theme.textDim
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 22),

            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, color: UIColor) {
        label.text  = title.uppercased()
        label.textColor = color
        dot.backgroundColor = color
        pill.layer.borderColor = color.withAlphaComponent(0.3).cgColor
    }
}

// MARK: - BeatGridView

final class BeatGridView: UIView {
    static let dotSize: CGFloat = 5
    static let dotGap:  CGFloat = 2
    static let rowGap:  CGFloat = 5
    static let steps   = 16
    static let trackIds  = ["kick", "snare", "hat"]
    static let colors: [(CGFloat, CGFloat, CGFloat)] = [
        (1.00, 0.478, 0.349),
        (1.00, 0.820, 0.400),
        (0.608, 0.965, 1.00),
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

// MARK: - BeatActivityView

final class BeatActivityView: UIView {
    static let barW:  CGFloat = 6
    static let barGap: CGFloat = 4
    static let W = 4 * barW + 3 * barGap   // 36pt
    static let H = BeatGridView.H           // matches beat grid height

    private let bars: [UIView] = (0..<4).map { _ in UIView() }
    private var heights: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        var cs: [NSLayoutConstraint] = []
        for (i, bar) in bars.enumerated() {
            bar.layer.cornerRadius = Self.barW / 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)
            let hc = bar.heightAnchor.constraint(equalToConstant: 2)
            heights.append(hc)
            cs += [
                bar.widthAnchor.constraint(equalToConstant: Self.barW),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor),
                bar.leadingAnchor.constraint(equalTo: leadingAnchor,
                    constant: CGFloat(i) * (Self.barW + Self.barGap)),
                hc,
            ]
        }
        NSLayoutConstraint.activate(cs)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rows: [String: [Bool]], color: UIColor) {
        var counts = [0, 0, 0, 0]
        for steps in rows.values {
            for beat in 0..<4 {
                for step in 0..<4 {
                    let idx = beat * 4 + step
                    if idx < steps.count && steps[idx] { counts[beat] += 1 }
                }
            }
        }
        let peak = max(1, counts.max() ?? 1)
        for (i, bar) in bars.enumerated() {
            let ratio = CGFloat(counts[i]) / CGFloat(peak)
            heights[i].constant = 2 + ratio * (Self.H - 2)
            bar.backgroundColor = color.withAlphaComponent(0.25 + 0.55 * ratio)
        }
    }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
