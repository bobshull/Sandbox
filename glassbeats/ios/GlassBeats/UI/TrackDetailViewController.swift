import UIKit

final class TrackDetailViewController: UIViewController {

    let track: Track
    private var effects: TrackEffects
    private var volume: Float

    var onVolumeChange: ((Float) -> Void)?
    var onEffectsChange: ((TrackEffects) -> Void)?
    var onReset: (() -> Void)?

    private let panel = UIView()

    private let volFader   = FaderControl()
    private let panFader   = FaderControl()
    private let pitchFader = FaderControl()
    private let rvbFader   = FaderControl()
    private let dlyFader   = FaderControl()
    private let dstFader   = FaderControl()

    private let dlySegment = UISegmentedControl(
        items: TrackEffects.DelaySyncDivision.allCases.map { $0.displayName }
    )

    init(track: Track, volume: Float, effects: TrackEffects) {
        self.track   = track
        self.volume  = volume
        self.effects = effects
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)

        buildPanel()
        populateValues()
    }

    // MARK: - Panel

    private func buildPanel() {
        let bg = UIButton(type: .custom)
        bg.frame = view.bounds
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bg.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(bg)

        panel.backgroundColor    = Theme.backgroundElevated2
        panel.layer.cornerRadius = 16
        panel.layer.borderWidth  = 1.5
        let trackColor = ColorTheme.current.color(for: track.id)
        panel.layer.borderColor  = trackColor.withAlphaComponent(0.8).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let nameLabel = UILabel()
        nameLabel.text      = track.name
        nameLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = trackColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(nameLabel)

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = Theme.textFaint
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(closeBtn)

        let resetBtn = UIButton(type: .system)
        resetBtn.setImage(UIImage(systemName: "arrow.counterclockwise",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        resetBtn.tintColor = Theme.textDim
        resetBtn.accessibilityLabel = "Reset"
        resetBtn.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(resetBtn)

        let headerDiv = makeDivider()
        panel.addSubview(headerDiv)

        configureFader(volFader,   title: "Vol",   min: 0,   max: 1)
        configureFader(panFader,   title: "Pan",   min: -1,  max: 1)
        panFader.snapPoints  = [0]; panFader.snapRadius  = 0.08
        configureFader(pitchFader, title: "Pitch", min: -12, max: 12)
        pitchFader.snapPoints = [0]; pitchFader.snapRadius = 1.0
        configureFader(rvbFader,   title: "Rvb",   min: 0,   max: 100)
        configureFader(dlyFader,   title: "Dly",   min: 0,   max: 100)
        configureFader(dstFader,   title: "Dst",   min: 0,   max: 100)

        volFader.addTarget(self,   action: #selector(volChanged),   for: .valueChanged)
        panFader.addTarget(self,   action: #selector(panChanged),   for: .valueChanged)
        pitchFader.addTarget(self, action: #selector(pitchChanged), for: .valueChanged)
        rvbFader.addTarget(self,   action: #selector(rvbChanged),   for: .valueChanged)
        dlyFader.addTarget(self,   action: #selector(dlyChanged),   for: .valueChanged)
        dstFader.addTarget(self,   action: #selector(dstChanged),   for: .valueChanged)

        let faderStack = UIStackView(arrangedSubviews: [volFader, panFader, pitchFader, rvbFader, dlyFader, dstFader])
        faderStack.axis         = .horizontal
        faderStack.distribution = .fillEqually
        faderStack.spacing      = 8
        faderStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(faderStack)

        dlySegment.selectedSegmentTintColor = Theme.accent
        dlySegment.setTitleTextAttributes([.foregroundColor: Theme.text], for: .selected)
        dlySegment.setTitleTextAttributes([.foregroundColor: Theme.textDim as Any], for: .normal)
        dlySegment.addTarget(self, action: #selector(dlySegChanged), for: .valueChanged)
        dlySegment.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(dlySegment)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 380),

            nameLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),

            closeBtn.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),

            resetBtn.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            resetBtn.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -10),
            resetBtn.widthAnchor.constraint(equalToConstant: 28),
            resetBtn.heightAnchor.constraint(equalToConstant: 28),

            headerDiv.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            headerDiv.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            headerDiv.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            headerDiv.heightAnchor.constraint(equalToConstant: 1),

            faderStack.topAnchor.constraint(equalTo: headerDiv.bottomAnchor, constant: 12),
            faderStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            faderStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            faderStack.heightAnchor.constraint(equalToConstant: 160),

            dlySegment.topAnchor.constraint(equalTo: faderStack.bottomAnchor, constant: 12),
            dlySegment.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            dlySegment.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            dlySegment.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Populate

    private func populateValues() {
        volFader.value     = volume
        volFader.valueText = pctVol(volume)

        panFader.value     = effects.pan
        panFader.valueText = panText(effects.pan)

        pitchFader.value     = effects.pitch
        pitchFader.valueText = pitchText(effects.pitch)

        rvbFader.value     = effects.reverbWet
        rvbFader.valueText = pct100(effects.reverbWet)

        dlyFader.value     = effects.delayWet
        dlyFader.valueText = pct100(effects.delayWet)
        dlySegment.selectedSegmentIndex = TrackEffects.DelaySyncDivision.allCases
            .firstIndex(of: effects.delaySyncDivision) ?? 1

        dstFader.value     = effects.distortionWet
        dstFader.valueText = pct100(effects.distortionWet)

        updateDlySegState()
    }

    // MARK: - Delay segment state

    private func updateDlySegState() {
        let active = effects.delayWet > 0
        dlySegment.isEnabled = active
        dlySegment.alpha     = active ? 1 : 0.35
    }

    // MARK: - Actions

    @objc private func close() { dismiss(animated: true) }

    @objc private func resetTapped() {
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        volume  = 1.0
        effects = .default
        populateValues()
        for fader in [volFader, panFader, pitchFader, rvbFader, dlyFader, dstFader] {
            fader.setNeedsDisplay()
        }
        onReset?()
    }

    @objc private func volChanged() {
        volume             = volFader.value
        volFader.valueText = pctVol(volume)
        volFader.setNeedsDisplay()
        onVolumeChange?(volume)
    }

    @objc private func panChanged() {
        effects.pan        = panFader.value
        panFader.valueText = panText(effects.pan)
        panFader.setNeedsDisplay()
        onEffectsChange?(effects)
    }

    @objc private func pitchChanged() {
        let semitones          = Float(Int(pitchFader.value.rounded()))
        effects.pitch          = semitones
        pitchFader.value       = semitones
        pitchFader.valueText   = pitchText(semitones)
        pitchFader.setNeedsDisplay()
        onEffectsChange?(effects)
    }

    @objc private func rvbChanged() {
        effects.reverbWet  = rvbFader.value
        rvbFader.valueText = pct100(effects.reverbWet)
        rvbFader.setNeedsDisplay()
        onEffectsChange?(effects)
    }

    @objc private func dlyChanged() {
        effects.delayWet   = dlyFader.value
        dlyFader.valueText = pct100(effects.delayWet)
        dlyFader.setNeedsDisplay()
        updateDlySegState()
        onEffectsChange?(effects)
    }

    @objc private func dstChanged() {
        effects.distortionWet = dstFader.value
        dstFader.valueText    = pct100(effects.distortionWet)
        dstFader.setNeedsDisplay()
        onEffectsChange?(effects)
    }

    @objc private func dlySegChanged() {
        let all = TrackEffects.DelaySyncDivision.allCases
        let idx = dlySegment.selectedSegmentIndex
        if all.indices.contains(idx) { effects.delaySyncDivision = all[idx] }
        onEffectsChange?(effects)
    }

    // MARK: - Helpers

    private func pctVol(_ v: Float) -> String { "\(Int((v * 100).rounded()))%" }
    private func pct100(_ v: Float) -> String { "\(Int(v.rounded()))%" }

    private func panText(_ v: Float) -> String {
        let pct = Int((abs(v) * 100).rounded())
        if pct == 0 { return "C" }
        return v < 0 ? "L\(pct)" : "R\(pct)"
    }

    private func pitchText(_ v: Float) -> String {
        let s = Int(v.rounded())
        if s == 0 { return "0st" }
        return s > 0 ? "+\(s)st" : "\(s)st"
    }

    private func configureFader(_ f: FaderControl, title: String, min: Float, max: Float) {
        f.minimumValue = min
        f.maximumValue = max
        f.trackColor   = ColorTheme.current.color(for: track.id)
        f.title        = title
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.border
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}
