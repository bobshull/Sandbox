import UIKit
import Combine

protocol SequencerViewDelegate: AnyObject {
    func sequencer(toggleStep trackId: String, step: Int)
    func sequencerDidRequestPatternLength(_ length: Int)
    func sequencerDidRequestTrackActions(_ track: Track)
    func sequencerDidRequestBarActions(barIndex: Int)
    func sequencerDidToggleAccent(isAccented: Bool)
}

/// Scrolling grid where each row pins its track header to the leading edge
/// while the cells scroll horizontally. All row scroll views share their
/// offset so they move in lockstep.
///
/// Paging: always shows 16 cells (one bar). In 32-step mode, `activePage`
/// selects which bar is visible; cells are offset by `activePage * 16`.
final class SequencerView: UIView, UIScrollViewDelegate, TrackHeaderViewDelegate {

    weak var delegate: SequencerViewDelegate?

    private let store: Store
    private let engine: AudioEngine
    private var cancellables = Set<AnyCancellable>()

    private let trackStack = UIStackView()
    private let headerRow = UIView()
    private var stepLabels: [UILabel] = []
    private let headerLabelStack = UIStackView()
    private var headerPageWidthConstraint: NSLayoutConstraint?
    private var rows: [RowView] = []
    private var syncing = false

    // Easter egg state (1-bar mode overscroll gag)
    private var isEasterEggAnimating = false
    private var easterEggCooldownUntil: Date = .distantPast
    // 0=inactive 1=doubleTap 2=tripleTap 3=buzzing; only advances forward until reset at zero
    private var easterEggHapticZone = 0
    private var easterEggHapticBucket = 0

    // Page state (UI-only; not persisted to Store)
    private var activePage: Int = 0

    /// The currently visible bar index (0 or 1) — used by MainViewController for context menus.
    var currentBar: Int { activePage }

    // Bar 1 / Bar 2 toggles — lives in the header corner, only shown in 32-step mode
    private let bar1Button = UIButton(type: .system)
    private let bar2Button = UIButton(type: .system)
    private let barButtonStack = UIStackView()

    private struct RowView {
        let track: Track
        let header: TrackHeaderView
        let scrollView: UIScrollView
        let cellStack: UIStackView
        var cells: [CellButton]
        var pageWidthConstraint: NSLayoutConstraint?
    }

    private let headerColumnWidth: CGFloat = 150
    private let cellSpacing: CGFloat = 3
    private let beatGap: CGFloat = 8

    init(store: Store, engine: AudioEngine) {
        self.store = store
        self.engine = engine
        super.init(frame: .zero)
        configure()
        bind()
        applyState()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    private func configure() {
        // ── Step number header row (contains bar buttons in its corner) ───
        let hdr = makeHeaderRow()
        hdr.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hdr)

        // ── Track grid ───────────────────────────────────────────────────
        trackStack.axis = .vertical
        trackStack.spacing = 4
        trackStack.distribution = .fillEqually
        trackStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackStack)

        for track in Tracks.all {
            trackStack.addArrangedSubview(makeTrackRow(track: track))
        }

        NSLayoutConstraint.activate([
            hdr.topAnchor.constraint(equalTo: topAnchor),
            hdr.leadingAnchor.constraint(equalTo: leadingAnchor),
            hdr.trailingAnchor.constraint(equalTo: trailingAnchor),
            hdr.heightAnchor.constraint(equalToConstant: 24),

            trackStack.topAnchor.constraint(equalTo: hdr.bottomAnchor, constant: 4),
            trackStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configureBarButton(_ button: UIButton, title: String, index: Int) {
        button.tag = index
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs; out.font = .systemFont(ofSize: 12, weight: .semibold); return out
        }
        cfg.image = UIImage(systemName: "speaker.wave.2.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        cfg.imagePlacement = .leading
        cfg.imagePadding = 4
        cfg.background.cornerRadius = 6
        cfg.background.strokeWidth = 1
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
        button.configuration = cfg
        button.addTarget(self, action: #selector(barButtonTapped(_:)), for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(barLongPressed(_:)))
        longPress.minimumPressDuration = 0.4
        button.addGestureRecognizer(longPress)
    }

    // Enabled (in loop) = accent. Disabled (muted from loop) = dim.
    // Current view gets a subtle underline dot so you know where you are.
    private func syncBarButtons() {
        let enabled = store.enabledBars
        let primary = ColorTheme.current.primaryColor
        for (idx, button) in [(0, bar1Button), (1, bar2Button)] {
            let isEnabled = idx < enabled.count && enabled[idx]
            var cfg = button.configuration ?? .plain()
            let iconName = isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
            cfg.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
            cfg.background.backgroundColor = isEnabled ? primary.withAlphaComponent(0.22) : Theme.backgroundElevated
            cfg.background.strokeColor     = isEnabled ? primary : Theme.border
            cfg.baseForegroundColor        = isEnabled ? primary : Theme.textFaint
            button.configuration = cfg
            button.alpha = isEnabled ? 1.0 : 0.45
        }
    }

    private func updateBarButtonsVisible() {
        barButtonStack.isHidden = store.patternLength != 32
    }

    // Rebuilds step labels and cells to match the current pattern length,
    // and enables/disables paging. Called whenever patternLength changes.
    private func rebuildForPatternLength(flashScrollbar: Bool = false) {
        let count = store.patternLength
        let is32 = count == 32

        // ── Step labels ──────────────────────────────────────────────────
        for v in headerLabelStack.arrangedSubviews {
            headerLabelStack.removeArrangedSubview(v); v.removeFromSuperview()
        }
        stepLabels = (0..<count).map { i in
            let l = UILabel()
            l.text = "\(i + 1)"
            l.font = .monospacedSystemFont(ofSize: 10, weight: (i % 4 == 0) ? .bold : .regular)
            l.textColor = (i % 4 == 0) ? Theme.text : Theme.textFaint
            l.textAlignment = .center
            return l
        }
        for g in 0..<(count / 4) {
            let group = UIStackView(arrangedSubviews: Array(stepLabels[g*4..<g*4+4]))
            group.axis = .horizontal; group.distribution = .fillEqually; group.spacing = cellSpacing
            headerLabelStack.addArrangedSubview(group)
        }

        headerPageWidthConstraint?.isActive = false
        let numPages = CGFloat(count) / 16.0
        let hc = headerLabelStack.widthAnchor.constraint(equalTo: headerScrollView.frameLayoutGuide.widthAnchor, multiplier: numPages)
        hc.isActive = true
        headerPageWidthConstraint = hc
        headerScrollView.isPagingEnabled = is32

        // ── Track cells ──────────────────────────────────────────────────
        for i in 0..<rows.count {
            let row = rows[i]
            for v in row.cellStack.arrangedSubviews {
                row.cellStack.removeArrangedSubview(v); v.removeFromSuperview()
            }
            var newCells: [CellButton] = []
            for g in 0..<(count / 4) {
                let group = UIStackView()
                group.axis = .horizontal; group.distribution = .fillEqually; group.spacing = cellSpacing
                for step in g*4..<g*4+4 {
                    let cell = CellButton()
                    let theme = ColorTheme.current
                    cell.trackColor = theme.color(for: row.track.id)
                    cell.accentColor = theme.accent(for: row.track.id)
                    cell.isBeat = (step % 4 == 0)
                    cell.accessibilityLabel = "\(row.track.name) step \(step + 1)"
                    cell.tag = step
                    cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside)
                    addAccentGestures(to: cell)
                    cell.translatesAutoresizingMaskIntoConstraints = false
                    group.addArrangedSubview(cell)
                    newCells.append(cell)
                }
                row.cellStack.addArrangedSubview(group)
            }
            rows[i].cells = newCells
            rows[i].pageWidthConstraint?.isActive = false
            let c = row.cellStack.widthAnchor.constraint(equalTo: row.scrollView.frameLayoutGuide.widthAnchor, multiplier: numPages)
            c.isActive = true
            rows[i].pageWidthConstraint = c
            row.scrollView.isPagingEnabled = is32
        }

        scrollToPage(0, animated: false)
        updateBarButtonsVisible()
        syncBarButtons()

        if flashScrollbar && is32 && !engine.isPlaying {
            // Briefly peek into Bar 2 so the user knows it's there
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else { return }
                let peekX = (self.rows.first?.scrollView.bounds.width ?? 200) * 0.35
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                    for row in self.rows { row.scrollView.contentOffset = CGPoint(x: peekX, y: 0) }
                    self.headerScrollView.contentOffset = CGPoint(x: peekX, y: 0)
                } completion: { _ in
                    UIView.animate(withDuration: 0.25, delay: 0.05, options: .curveEaseIn) {
                        for row in self.rows { row.scrollView.contentOffset = .zero }
                        self.headerScrollView.contentOffset = .zero
                    }
                }
            }
        }
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        activePage = page
        for row in rows {
            let x = CGFloat(page) * row.scrollView.bounds.width
            row.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
        }
        let hx = CGFloat(page) * headerScrollView.bounds.width
        headerScrollView.setContentOffset(CGPoint(x: hx, y: 0), animated: animated)
        syncBarButtons()
        syncVolumes()
        syncEffects()
    }

    private var headerScrollView: UIScrollView!

    private func makeHeaderRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let corner = UIView()
        corner.backgroundColor = .clear
        corner.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(corner)

        // Bar 1 / Bar 2 playback toggles — sit in the corner, only shown in 32-step mode
        configureBarButton(bar1Button, title: "Bar 1", index: 0)
        configureBarButton(bar2Button, title: "Bar 2", index: 1)

        barButtonStack.axis = .horizontal
        barButtonStack.spacing = 6
        barButtonStack.translatesAutoresizingMaskIntoConstraints = false
        barButtonStack.addArrangedSubview(bar1Button)
        barButtonStack.addArrangedSubview(bar2Button)
        barButtonStack.isHidden = store.patternLength != 32
        corner.addSubview(barButtonStack)

        // Swipe on the corner header also navigates bars
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleBarSwipe(_:)))
            swipe.direction = direction
            corner.addGestureRecognizer(swipe)
        }

        NSLayoutConstraint.activate([
            barButtonStack.centerXAnchor.constraint(equalTo: corner.centerXAnchor),
            barButtonStack.centerYAnchor.constraint(equalTo: corner.centerYAnchor),
        ])

        syncBarButtons()

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.isUserInteractionEnabled = false   // header just follows; cells scroll
        scroll.tag = -1
        row.addSubview(scroll)
        headerScrollView = scroll

        headerLabelStack.axis = .horizontal
        headerLabelStack.distribution = .fillEqually
        headerLabelStack.spacing = beatGap
        headerLabelStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(headerLabelStack)

        let minGroupW = 4 * 28.0 + 3 * cellSpacing
        let minLabelW = 4 * minGroupW + 3 * beatGap
        NSLayoutConstraint.activate([
            corner.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            corner.topAnchor.constraint(equalTo: row.topAnchor),
            corner.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            corner.widthAnchor.constraint(equalToConstant: headerColumnWidth),

            scroll.leadingAnchor.constraint(equalTo: corner.trailingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: row.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            headerLabelStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            headerLabelStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            headerLabelStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            headerLabelStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            headerLabelStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            headerLabelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: minLabelW),
        ])
        return row
    }

    private func makeTrackRow(track: Track) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let header = TrackHeaderView(track: track)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.delegate = self
        row.addSubview(header)

        let scroll = HorizontalOnlyScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.delegate = self
        scroll.alwaysBounceHorizontal = true
        scroll.tag = Tracks.all.firstIndex(where: { $0.id == track.id }) ?? 0
        row.addSubview(scroll)

        let cellStack = UIStackView()
        cellStack.axis = .horizontal
        cellStack.distribution = .fillEqually
        cellStack.spacing = beatGap
        cellStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(cellStack)

        var cells: [CellButton] = []
        for g in 0..<4 {
            let group = UIStackView()
            group.axis = .horizontal
            group.distribution = .fillEqually
            group.spacing = cellSpacing
            for localStep in g*4..<g*4+4 {
                let cell = CellButton()
                let theme = ColorTheme.current
                cell.trackColor = theme.color(for: track.id)
                cell.accentColor = theme.accent(for: track.id)
                cell.isBeat = (localStep % 4 == 0)
                cell.accessibilityLabel = "\(track.name) step \(localStep + 1)"
                cell.tag = localStep   // local 0-15; actual step = activePage*16 + tag
                cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside)
                addAccentGestures(to: cell)
                cell.translatesAutoresizingMaskIntoConstraints = false
                group.addArrangedSubview(cell)
                cells.append(cell)
            }
            cellStack.addArrangedSubview(group)
        }

        let minGroupW = 4 * 28.0 + 3 * cellSpacing
        let minCellW = 4 * minGroupW + 3 * beatGap
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            header.topAnchor.constraint(equalTo: row.topAnchor),
            header.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            header.widthAnchor.constraint(equalToConstant: headerColumnWidth),

            scroll.leadingAnchor.constraint(equalTo: header.trailingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: row.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            cellStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            cellStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            cellStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            cellStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            cellStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            cellStack.widthAnchor.constraint(greaterThanOrEqualToConstant: minCellW),
        ])

        rows.append(RowView(track: track, header: header, scrollView: scroll, cellStack: cellStack, cells: cells, pageWidthConstraint: nil))
        return row
    }

    // MARK: - Binding

    private func bind() {
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme),
                                               name: .colorThemeDidChange, object: nil)
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self else { return }
                switch section {
                case .pattern:
                    self.syncPattern()
                    self.syncAccents()
                case .accent: self.syncAccents()
                case .patternLength:
                    let needsRebuild = store.patternLength != (self.rows.first?.cells.count ?? 0)
                    if needsRebuild {
                        self.rebuildForPatternLength(flashScrollbar: true)
                    } else {
                        self.updateBarButtonsVisible()
                        self.syncBarButtons()
                    }
                    self.syncPattern()
                    self.syncAccents()
                    self.syncPlayhead()
                case .load:
                    self.rebuildForPatternLength()
                    self.syncPattern()
                    self.syncAccents()
                    self.syncPlayhead()
                    self.syncMutes()
                    self.syncVolumes()
                    self.syncEffects()
                case .step: self.syncPlayhead()
                case .mutes: self.syncMutes()
                case .volumes: self.syncVolumes()
                case .effects: self.syncEffects()
                default: break
                }
            }
            .store(in: &cancellables)
    }

    private func applyState() {
        rebuildForPatternLength()
        syncPattern()
        syncAccents()
        syncMutes()
        syncVolumes()
        syncEffects()
        applyTheme()
    }

    // MARK: - Sync helpers

    private func syncPattern() {
        for row in rows {
            let arr = store.rows[row.track.id] ?? []
            for cell in row.cells {
                cell.isOn = arr.indices.contains(cell.tag) ? arr[cell.tag] : false
            }
        }
        syncBarDim()
    }

    private func syncBarDim() {
        let enabled = store.enabledBars
        let is32 = store.patternLength == 32
        UIView.animate(withDuration: 0.18) {
            for row in self.rows {
                for cell in row.cells {
                    let barIdx = cell.tag / 16
                    let active = !is32 || (barIdx < enabled.count && enabled[barIdx])
                    cell.alpha = active ? 1.0 : 0.3
                }
            }
        }
    }

    private func syncPlayhead() {
        let active = store.activeStep
        for row in rows {
            for cell in row.cells {
                cell.isPlayhead = (cell.tag == active)
            }
        }
        let primary = ColorTheme.current.primaryColor
        for (i, label) in stepLabels.enumerated() {
            label.textColor = (i == active) ? primary : ((i % 4 == 0) ? Theme.text : Theme.textFaint)
        }
        if engine.isPlaying, store.patternLength == 32, active >= 0 {
            let bar = active / 16
            if bar != activePage { scrollToPage(bar, animated: true) }
        }
    }

    private func syncMutes() {
        for row in rows {
            let muted = store.mutes[row.track.id] ?? false
            row.header.setMuted(muted)
            UIView.animate(withDuration: 0.18) {
                row.scrollView.alpha = muted ? 0.28 : 1.0
            }
        }
    }

    private func syncVolumes() {
        let bar = store.patternLength == 32 ? activePage : 0
        let vols = store.volumes(for: bar)
        for row in rows {
            row.header.setVolume(vols[row.track.id] ?? 1.0)
        }
    }

    private func syncEffects() {
        let bar = store.patternLength == 32 ? activePage : 0
        let efxs = store.effects(for: bar)
        for row in rows {
            row.header.setEffects(efxs[row.track.id] ?? .default)
        }
    }

    private func syncAccents() {
        for row in rows {
            let arr = store.accents[row.track.id] ?? []
            for cell in row.cells {
                cell.isAccented = arr.indices.contains(cell.tag) && arr[cell.tag]
            }
        }
    }

    // MARK: - Cell tap

    @objc private func cellTapped(_ sender: CellButton) {
        guard let row = rows.first(where: { $0.cells.contains(sender) }) else { return }
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        delegate?.sequencer(toggleStep: row.track.id, step: sender.tag)
    }

    @objc private func applyTheme() {
        let theme = ColorTheme.current
        for row in rows {
            let c = theme.color(for: row.track.id)
            let a = theme.accent(for: row.track.id)
            for cell in row.cells { cell.trackColor = c; cell.accentColor = a }
            row.header.applyThemeColor(c)
        }
        syncBarButtons()
        syncPlayhead()
    }

    // MARK: - Bar buttons + swipe

    // Tap: toggle that bar in/out of the playback loop
    @objc private func barButtonTapped(_ sender: UIButton) {
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        store.toggleBar(sender.tag)
    }

    // Swipe on the header corner: programmatically page the scroll views
    @objc private func handleBarSwipe(_ gr: UISwipeGestureRecognizer) {
        guard store.patternLength == 32 else { return }
        let target = gr.direction == .left ? min(activePage + 1, 1) : max(activePage - 1, 0)
        guard target != activePage else { return }
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        scrollToPage(target, animated: true)
    }

    // MARK: - TrackHeaderViewDelegate

    func trackHeaderDidTapPreview(_ track: Track) {
        engine.preview(trackId: track.id)
    }

    func trackHeaderDidToggleMute(_ track: Track) {
        store.toggleMute(trackId: track.id)
    }

    func trackHeaderDidChangeVolume(_ track: Track, value: Float) {
        let bar = store.patternLength == 32 ? activePage : 0
        store.setVolume(trackId: track.id, value: value, bar: bar)
        if liveEngineShouldFollow(bar: bar) {
            engine.setTrackGain(track.id, value)
        }
    }

    func trackHeaderDidChangeEffects(_ track: Track, effects: TrackEffects) {
        let bar = store.patternLength == 32 ? activePage : 0
        store.setTrackEffects(trackId: track.id, effects, bar: bar)
        if liveEngineShouldFollow(bar: bar) {
            engine.setTrackEffects(track.id, effects)
        }
    }

    func trackHeaderDidResetTrack(_ track: Track) {
        let bar = store.patternLength == 32 ? activePage : 0
        store.resetTrackControls(trackId: track.id, bar: bar)
        if liveEngineShouldFollow(bar: bar) {
            engine.setTrackGain(track.id, 1.0)
            engine.setTrackEffects(track.id, .default)
        }
    }

    private func liveEngineShouldFollow(bar: Int) -> Bool {
        guard engine.isPlaying, store.patternLength == 32, store.activeStep >= 0 else { return true }
        return store.activeStep / 16 == bar
    }

    func trackHeaderDidRequestActions(_ track: Track) {
        delegate?.sequencerDidRequestTrackActions(track)
    }

    // MARK: - Bar long press → bar actions

    @objc private func barLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        let barIndex: Int
        if gr.view === bar1Button { barIndex = 0 }
        else if gr.view === bar2Button { barIndex = 1 }
        else { return }
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        delegate?.sequencerDidRequestBarActions(barIndex: barIndex)
    }

    // MARK: - Cell accent gestures

    private func addAccentGestures(to cell: CellButton) {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(cellLongPressed(_:)))
        longPress.minimumPressDuration = 0.4
        // cancelsTouchesInView = true (default): suppresses touchUpInside on long press ✓
        cell.addGestureRecognizer(longPress)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(cellDoubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        // cancelsTouchesInView = false: both taps fire touchUpInside, cancelling each other out
        // (net step state unchanged), then this GR fires to toggle accent ✓
        doubleTap.cancelsTouchesInView = false
        cell.addGestureRecognizer(doubleTap)
    }

    @objc private func cellLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began, let cell = gr.view as? CellButton else { return }
        // cell.isOn is reliable here: long press suppresses touchUpInside, step state unchanged
        guard cell.isOn else { return }
        guard let row = rows.first(where: { $0.cells.contains(cell) }) else { return }
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        store.toggleAccent(trackId: row.track.id, step: cell.tag)
        let newAccented = store.accents[row.track.id]?[cell.tag] ?? false
        cell.pulseAccent(on: newAccented)
        delegate?.sequencerDidToggleAccent(isAccented: newAccented)
    }

    @objc private func cellDoubleTapped(_ gr: UITapGestureRecognizer) {
        guard let cell = gr.view as? CellButton else { return }
        // cell.isOn is reliable here: the two touchUpInside events toggled the store twice
        // (net: unchanged), but syncPattern hasn't run yet, so cell.isOn still reflects
        // the original state — check it to ignore double-taps on empty cells
        guard cell.isOn else { return }
        guard let row = rows.first(where: { $0.cells.contains(cell) }) else { return }
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        store.toggleAccent(trackId: row.track.id, step: cell.tag)
        let newAccented = store.accents[row.track.id]?[cell.tag] ?? false
        cell.pulseAccent(on: newAccented)
        delegate?.sequencerDidToggleAccent(isAccented: newAccented)
    }

    // MARK: - Scroll sync

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        let offset = CGPoint(x: scrollView.contentOffset.x, y: 0)
        if scrollView !== headerScrollView {
            headerScrollView.contentOffset = offset
        }
        for row in rows where row.scrollView !== scrollView {
            row.scrollView.contentOffset = offset
        }
        // Drive progressive haptics while the user is actively rubber-banding (1-bar only)
        if store.patternLength == 16, scrollView !== headerScrollView, scrollView.isDragging {
            easterEggHapticTick(overscroll: abs(scrollView.contentOffset.x))
        } else if !scrollView.isDragging {
            easterEggHapticZone = 0
            easterEggHapticBucket = 0
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.isPagingEnabled, scrollView !== headerScrollView else { return }
        let w = scrollView.bounds.width
        guard w > 0 else { return }
        let page = Int(scrollView.contentOffset.x / w + 0.5)
        if page != activePage {
            activePage = page
            syncBarButtons()
            syncVolumes()
            syncEffects()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndDecelerating(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Only in 1-bar mode; 2-bar uses horizontal scroll for real navigation
        guard store.patternLength == 16 else { return }
        guard scrollView !== headerScrollView else { return }
        guard !isEasterEggAnimating, Date() > easterEggCooldownUntil else { return }
        // Require intentional overscroll — small bounce bounces are < 44 pts
        let overscroll = abs(scrollView.contentOffset.x)
        guard overscroll > 180 else { return }
        triggerEasterEgg(contentOffset: scrollView.contentOffset.x, scrollViewWidth: scrollView.bounds.width)
    }

    // MARK: - Easter Egg

    private func triggerEasterEgg(contentOffset: CGFloat, scrollViewWidth: CGFloat) {
        isEasterEggAnimating = true
        easterEggCooldownUntil = Date().addingTimeInterval(3.0)

        let allCells = rows.flatMap { $0.cells }
        // Fly in the direction the user was dragging: positive offset = dragged left = fly right
        let direction: CGFloat = contentOffset >= 0 ? 1 : -1
        let exitX: CGFloat  =  direction * (scrollViewWidth + 80)
        let entryX: CGFloat = -direction * (scrollViewWidth + 80)

        if AppSettings.hapticsEnabled {
            // Solid double-hit on trigger: rigid "crack" then a heavy thump 80ms later
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.prepare()
            gen.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }

        // Reduced motion: simple fade instead of fly
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2) {
                allCells.forEach { $0.alpha = 0 }
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    allCells.forEach { $0.alpha = 1 }
                } completion: { [weak self] _ in
                    self?.isEasterEggAnimating = false
                }
            }
            return
        }

        // Phase 1: slide off to the left, staggered left-to-right by column
        let flyOffDuration: Double = 0.18
        let flyOffStagger: Double = 0.008
        for cell in allCells {
            // Leading-edge tile goes first: fly-left → tag 0 leads; fly-right → tag 15 leads
            let col = direction > 0 ? Double(15 - cell.tag) : Double(cell.tag)
            UIView.animate(withDuration: flyOffDuration, delay: col * flyOffStagger,
                           options: .curveEaseIn) {
                cell.transform = CGAffineTransform(translationX: exitX, y: 0)
            }
        }

        // Phase 2: snap cells to the right edge (off-screen), then spring back in
        let snapDelay = flyOffDuration + Double(15) * flyOffStagger + 0.025
        let flyInDuration: Double = 0.30
        let flyInStagger: Double = 0.012
        DispatchQueue.main.asyncAfter(deadline: .now() + snapDelay) { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                allCells.forEach { $0.transform = CGAffineTransform(translationX: entryX, y: 0) }
            }
            for cell in allCells {
                let col = Double(cell.tag)
                UIView.animate(
                    withDuration: flyInDuration,
                    delay: col * flyInStagger,
                    usingSpringWithDamping: 0.72,
                    initialSpringVelocity: 0.9,
                    options: []
                ) {
                    cell.transform = .identity
                } completion: { finished in
                    // Active tiles get a brief glow on landing
                    if finished && cell.isOn { cell.pulseReturn() }
                }
            }
            // Snap-back haptic + unlock after all cells have settled
            let totalFlyIn = flyInDuration + Double(15) * flyInStagger + 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + totalFlyIn) { [weak self] in
                if AppSettings.hapticsEnabled {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                self?.isEasterEggAnimating = false
            }
        }
    }

    private func easterEggHapticTick(overscroll: CGFloat) {
        guard AppSettings.hapticsEnabled else { return }
        guard !isEasterEggAnimating else { return }

        // Full reset when they pull back to near-zero
        guard overscroll > 15 else {
            easterEggHapticZone = 0
            easterEggHapticBucket = 0
            return
        }

        // Determine target zone from current overscroll depth
        let targetZone: Int = overscroll < 60 ? 1 : overscroll < 110 ? 2 : 3

        // Zones only advance — no re-firing bursts on pullback
        if targetZone > easterEggHapticZone {
            easterEggHapticZone = targetZone
            switch targetZone {
            case 1:
                // Double tap: two light pulses
                fireHapticBurst(count: 2, style: .light, baseIntensity: 0.6, spacing: 0.09)
            case 2:
                // Triple tap: three medium pulses, each a bit heavier
                fireHapticBurst(count: 3, style: .medium, baseIntensity: 0.7, spacing: 0.08)
            case 3:
                // First buzz tick fires immediately on zone entry
                easterEggHapticBucket = Int(overscroll / 8.0)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
            default: break
            }
        }

        // Dense vibration ticks throughout buzz zone (intensity rises toward threshold)
        if easterEggHapticZone == 3 {
            let bucket = Int(overscroll / 8.0)
            guard bucket != easterEggHapticBucket else { return }
            easterEggHapticBucket = bucket
            let progress = min(1.0, (overscroll - 110) / 70)   // 0→1 across buzz zone
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6 + progress * 0.4)
        }
    }

    private func fireHapticBurst(count: Int, style: UIImpactFeedbackGenerator.FeedbackStyle,
                                  baseIntensity: CGFloat, spacing: TimeInterval) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred(intensity: baseIntensity)
        for i in 1..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + spacing * Double(i)) {
                UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: baseIntensity + CGFloat(i) * 0.08)
            }
        }
    }
}

private final class HorizontalOnlyScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let pan = gr as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gr)
        }
        let t = pan.translation(in: self)
        return abs(t.x) > abs(t.y) * 1.5
    }
}
