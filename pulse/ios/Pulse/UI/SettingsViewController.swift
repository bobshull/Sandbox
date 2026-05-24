import UIKit
import MessageUI

final class SettingsViewController: UIViewController {

    private let tableView   = UITableView(frame: .zero, style: .plain)
    private let titlePill   = UIButton(type: .custom)
    private let feedbackBtn = UIButton(type: .system)

    private enum Row { case syncHaptics, bpmAppearance }
    private let rows: [Row] = [.syncHaptics, .bpmAppearance]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        tableView.backgroundColor = Theme.background
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))
        tableView.tableFooterView = makeVersionFooter()
        tableView.register(SyncHapticsPairCell.self,   forCellReuseIdentifier: SyncHapticsPairCell.reuseID)
        tableView.register(BpmAppearancePairCell.self, forCellReuseIdentifier: BpmAppearancePairCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let header = buildHeader()
        view.addSubview(header)
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange),
                                               name: .colorThemeDidChange, object: nil)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 34),

            tableView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 58),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false

        var pillCfg = UIButton.Configuration.plain()
        pillCfg.image = UIImage(systemName: "gear",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        pillCfg.imagePadding = 6
        pillCfg.title = "Settings"
        pillCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var out = a; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        pillCfg.baseForegroundColor = Theme.text
        pillCfg.background.backgroundColor = Theme.backgroundElevated
        pillCfg.background.strokeColor = ColorTheme.current.primaryColor.withAlphaComponent(0.55)
        pillCfg.background.strokeWidth = 1.5
        pillCfg.background.cornerRadius = 16
        pillCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
        titlePill.configuration = pillCfg
        titlePill.isUserInteractionEnabled = false
        titlePill.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titlePill)

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
            titlePill.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titlePill.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            closeBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeBtn.heightAnchor.constraint(equalToConstant: 34),
        ])
        return header
    }

    private func makeVersionFooter() -> UIView {
        let info    = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = info?["CFBundleVersion"] as? String ?? "—"

        let versionLabel = UILabel()
        versionLabel.text = "Pulse \(version) (\(build))"
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = Theme.textFaint

        let dot = UILabel()
        dot.text = "·"
        dot.font = .systemFont(ofSize: 12)
        dot.textColor = Theme.textFaint

        feedbackBtn.setTitle("Send Feedback", for: .normal)
        feedbackBtn.setTitleColor(ColorTheme.current.primaryColor, for: .normal)
        feedbackBtn.titleLabel?.font = .systemFont(ofSize: 12)
        feedbackBtn.addAction(UIAction { [weak self] _ in self?.sendFeedback() }, for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [versionLabel, dot, feedbackBtn])
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center

        let tagline = UILabel()
        tagline.text = "Every message is read and genuinely appreciated."
        tagline.font = .systemFont(ofSize: 11)
        tagline.textColor = Theme.textFaint
        tagline.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, tagline])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        footer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
        return footer
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    @objc private func themeDidChange() {
        let primary = ColorTheme.current.primaryColor
        var cfg = titlePill.configuration
        cfg?.background.strokeColor = primary.withAlphaComponent(0.55)
        titlePill.configuration = cfg
        feedbackBtn.setTitleColor(primary, for: .normal)
    }

    private func sendFeedback() {
        let info    = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = info?["CFBundleVersion"] as? String ?? "?"
        let subject = "Pulse \(version) (\(build)) Feedback"

        let device = UIDevice.current
        var report = "Pulse \(version) (\(build))\nDate: \(Date())\nDevice: \(device.model) — iOS \(device.systemVersion)\n\n"
        if let crash = CrashLogger.shared.crashLogData.flatMap({ String(data: $0, encoding: .utf8) }) {
            report += "--- Crash Log ---\n\(crash)"
        } else {
            report += "No crash log."
        }
        let attachmentData = report.data(using: .utf8) ?? Data()

        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.mailComposeDelegate = self
            vc.setToRecipients(["bobby@pulsemixer.app"])
            vc.setSubject(subject)
            vc.addAttachmentData(attachmentData, mimeType: "text/plain", fileName: "diagnostic_report.txt")
            present(vc, animated: true)
        } else {
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:bobby@pulsemixer.app?subject=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool { false }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .syncHaptics:
            let cell = tableView.dequeueReusableCell(withIdentifier: SyncHapticsPairCell.reuseID, for: indexPath) as! SyncHapticsPairCell
            cell.configure()
            return cell
        case .bpmAppearance:
            let cell = tableView.dequeueReusableCell(withIdentifier: BpmAppearancePairCell.reuseID, for: indexPath) as! BpmAppearancePairCell
            cell.configure()
            return cell
}
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        if result == .sent { CrashLogger.shared.clearLog() }
        controller.dismiss(animated: true)
    }
}

// MARK: - Shared card builder

private func makeSettingCard(content: UIView) -> UIView {
    let card = UIView()
    card.backgroundColor = Theme.backgroundElevated
    card.layer.cornerRadius = 6
    card.layer.borderColor = Theme.border.cgColor
    card.layer.borderWidth = 1
    content.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(content)
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
        content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
        content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        card.bottomAnchor.constraint(greaterThanOrEqualTo: content.bottomAnchor, constant: 14),
    ])
    return card
}

private func makePairRow(left: UIView, right: UIView) -> UIStackView {
    let pair = UIStackView(arrangedSubviews: [left, right])
    pair.axis = .horizontal
    pair.spacing = 10
    pair.distribution = .fillEqually
    pair.alignment = .top
    return pair
}

// MARK: - SyncHapticsPairCell  (left: iCloud Sync, right: Haptics)

final class SyncHapticsPairCell: UITableViewCell {
    static let reuseID = "SyncHapticsPairCell"

    private let cloudIconView    = UIImageView()
    private let cloudStatusLabel = UILabel()
    private let cloudSwitch      = UISwitch()
    private let hapticsSwitch    = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.background
        selectionStyle = .none
        setupLayout()
        cloudSwitch.addTarget(self, action: #selector(cloudToggled), for: .valueChanged)
        hapticsSwitch.addTarget(self, action: #selector(hapticsToggled), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .colorThemeDidChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        let available = FileManager.default.ubiquityIdentityToken != nil
        cloudSwitch.isOn = PatternStore.iCloudSyncEnabled
        cloudSwitch.isEnabled = available
        applyCloudState(enabled: available && PatternStore.iCloudSyncEnabled)
        hapticsSwitch.isOn = AppSettings.hapticsEnabled
        applyTheme()
    }

    @objc private func applyTheme() {
        let primary = ColorTheme.current.primaryColor
        cloudSwitch.onTintColor = primary
        hapticsSwitch.onTintColor = primary
    }

    private func setupLayout() {
        // iCloud card
        cloudIconView.contentMode = .scaleAspectFit
        cloudIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cloudIconView.widthAnchor.constraint(equalToConstant: 18),
            cloudIconView.heightAnchor.constraint(equalToConstant: 18),
        ])
        let cloudTitle = UILabel()
        cloudTitle.text = "iCloud Sync"
        cloudTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        cloudTitle.textColor = Theme.text
        let cloudTitleRow = UIStackView(arrangedSubviews: [cloudIconView, cloudTitle])
        cloudTitleRow.axis = .horizontal; cloudTitleRow.spacing = 6; cloudTitleRow.alignment = .center

        cloudStatusLabel.font = .systemFont(ofSize: 12)
        cloudStatusLabel.textColor = Theme.textFaint
        let cloudControlRow = UIStackView(arrangedSubviews: [cloudStatusLabel, UIView(), cloudSwitch])
        cloudControlRow.axis = .horizontal; cloudControlRow.spacing = 6; cloudControlRow.alignment = .center

        let cloudStack = UIStackView(arrangedSubviews: [cloudTitleRow, cloudControlRow])
        cloudStack.axis = .vertical; cloudStack.spacing = 10

        // Haptics card
        let hapticsIcon = UIImageView(image: UIImage(systemName: "hand.tap"))
        hapticsIcon.tintColor = Theme.textDim; hapticsIcon.contentMode = .scaleAspectFit
        hapticsIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hapticsIcon.widthAnchor.constraint(equalToConstant: 18),
            hapticsIcon.heightAnchor.constraint(equalToConstant: 18),
        ])
        let hapticsTitle = UILabel()
        hapticsTitle.text = "Haptics"
        hapticsTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        hapticsTitle.textColor = Theme.text
        let hapticsTitleRow = UIStackView(arrangedSubviews: [hapticsIcon, hapticsTitle])
        hapticsTitleRow.axis = .horizontal; hapticsTitleRow.spacing = 6; hapticsTitleRow.alignment = .center

        let hapticsDesc = UILabel()
        hapticsDesc.text = "Step taps, play/stop, and undo"
        hapticsDesc.font = .systemFont(ofSize: 12); hapticsDesc.textColor = Theme.textFaint
        let hapticsControlRow = UIStackView(arrangedSubviews: [hapticsDesc, UIView(), hapticsSwitch])
        hapticsControlRow.axis = .horizontal; hapticsControlRow.spacing = 6; hapticsControlRow.alignment = .center

        let hapticsStack = UIStackView(arrangedSubviews: [hapticsTitleRow, hapticsControlRow])
        hapticsStack.axis = .vertical; hapticsStack.spacing = 10

        let pair = makePairRow(left: makeSettingCard(content: cloudStack),
                               right: makeSettingCard(content: hapticsStack))
        pair.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pair)
        NSLayoutConstraint.activate([
            pair.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pair.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            pair.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            pair.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    @objc private func cloudToggled() {
        PatternStore.iCloudSyncEnabled = cloudSwitch.isOn
        applyCloudState(enabled: cloudSwitch.isOn)
    }

    private func applyCloudState(enabled: Bool) {
        let available = FileManager.default.ubiquityIdentityToken != nil
        if !available {
            cloudIconView.image = UIImage(systemName: "icloud.slash")
            cloudIconView.tintColor = Theme.textFaint
            cloudStatusLabel.text = "iCloud not available"
        } else if enabled {
            cloudIconView.image = UIImage(systemName: "checkmark.icloud.fill")
            cloudIconView.tintColor = UIColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1)
            cloudStatusLabel.text = "Synced to iCloud"
        } else {
            cloudIconView.image = UIImage(systemName: "xmark.icloud")
            cloudIconView.tintColor = Theme.textFaint
            cloudStatusLabel.text = "Sync off"
        }
    }

    @objc private func hapticsToggled() {
        AppSettings.hapticsEnabled = hapticsSwitch.isOn
    }
}

// MARK: - BpmAppearancePairCell  (left: Default BPM, right: Appearance)

final class BpmAppearancePairCell: UITableViewCell {
    static let reuseID = "BpmAppearancePairCell"

    private let slider     = UISlider()
    private let valueLabel = UILabel()
    private let segment    = UISegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.background
        selectionStyle = .none
        setupLayout()
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .colorThemeDidChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        let bpm = AppSettings.defaultTempo
        slider.minimumValue = 40; slider.maximumValue = 220
        slider.value = Float(bpm)
        valueLabel.text = "\(Int(bpm))"

        segment.removeAllSegments()
        for (i, theme) in ColorTheme.all.enumerated() {
            segment.insertSegment(withTitle: theme.name, at: i, animated: false)
            if theme.id == AppSettings.colorThemeId { segment.selectedSegmentIndex = i }
        }
        applyTheme()
    }

    @objc private func applyTheme() {
        let primary = ColorTheme.current.primaryColor
        valueLabel.textColor = primary
        slider.minimumTrackTintColor = primary
        colorSegments()
    }

    private func setupLayout() {
        // BPM card
        let bpmIcon = UIImageView(image: UIImage(systemName: "metronome"))
        bpmIcon.tintColor = Theme.textDim; bpmIcon.contentMode = .scaleAspectFit
        bpmIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bpmIcon.widthAnchor.constraint(equalToConstant: 18),
            bpmIcon.heightAnchor.constraint(equalToConstant: 18),
        ])
        let bpmTitle = UILabel()
        bpmTitle.text = "Default BPM"
        bpmTitle.font = .systemFont(ofSize: 14, weight: .semibold); bpmTitle.textColor = Theme.text

        valueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let bpmTitleRow = UIStackView(arrangedSubviews: [bpmIcon, bpmTitle, UIView(), valueLabel])
        bpmTitleRow.axis = .horizontal; bpmTitleRow.spacing = 6; bpmTitleRow.alignment = .center

        slider.maximumTrackTintColor = Theme.border
        let grip = Theme.makeGripThumb()
        slider.setThumbImage(grip, for: .normal)
        slider.setThumbImage(grip, for: .highlighted)

        let bpmDesc = UILabel()
        bpmDesc.text = "Applies to new patterns"
        bpmDesc.font = .systemFont(ofSize: 12); bpmDesc.textColor = Theme.textFaint

        let bpmStack = UIStackView(arrangedSubviews: [bpmTitleRow, slider, bpmDesc])
        bpmStack.axis = .vertical; bpmStack.spacing = 8

        // Appearance card
        let themeIcon = UIImageView(image: UIImage(systemName: "swatchpalette"))
        themeIcon.tintColor = Theme.textDim; themeIcon.contentMode = .scaleAspectFit
        themeIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            themeIcon.widthAnchor.constraint(equalToConstant: 18),
            themeIcon.heightAnchor.constraint(equalToConstant: 18),
        ])
        let themeTitle = UILabel()
        themeTitle.text = "Appearance"
        themeTitle.font = .systemFont(ofSize: 14, weight: .semibold); themeTitle.textColor = Theme.text
        let themeTitleRow = UIStackView(arrangedSubviews: [themeIcon, themeTitle])
        themeTitleRow.axis = .horizontal; themeTitleRow.spacing = 6; themeTitleRow.alignment = .center

        let themeDesc = UILabel()
        themeDesc.text = "Sets the system theme color"
        themeDesc.font = .systemFont(ofSize: 12); themeDesc.textColor = Theme.textFaint

        let themeStack = UIStackView(arrangedSubviews: [themeTitleRow, segment, themeDesc])
        themeStack.axis = .vertical; themeStack.spacing = 8

        let pair = makePairRow(left: makeSettingCard(content: bpmStack),
                               right: makeSettingCard(content: themeStack))
        pair.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pair)
        NSLayoutConstraint.activate([
            pair.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pair.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            pair.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            pair.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    private func colorSegments() {
        segment.setTitleTextAttributes([.foregroundColor: Theme.text], for: .normal)
        segment.setTitleTextAttributes([.foregroundColor: Theme.background], for: .selected)
        if segment.selectedSegmentIndex >= 0, segment.selectedSegmentIndex < ColorTheme.all.count {
            segment.selectedSegmentTintColor = ColorTheme.all[segment.selectedSegmentIndex].color(for: "kick")
        }
    }

    @objc private func sliderChanged() {
        let snapped = Double(slider.value).rounded()
        valueLabel.text = "\(Int(snapped))"
        AppSettings.defaultTempo = snapped
    }

    @objc private func segmentChanged() {
        colorSegments()
        guard segment.selectedSegmentIndex >= 0 else { return }
        AppSettings.colorThemeId = ColorTheme.all[segment.selectedSegmentIndex].id
    }
}
