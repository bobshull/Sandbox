import UIKit
import Combine

final class MainViewController: UIViewController, TransportViewDelegate, SequencerViewDelegate,
                                PatternLibraryDelegate {

    private let store = Store()
    private lazy var engine = AudioEngine(store: store)

    private lazy var transportView = TransportView(store: store)
    private lazy var sequencerView = SequencerView(store: store, engine: engine)
    private lazy var toast = ToastPresenter(host: view)

    private let patternsButton  = UIButton(type: .system)
    private let kitsButton      = UIButton(type: .system)
    private let undoButton      = UIButton(type: .system)
    private let moreButton      = UIButton(type: .system)
    private let settingsButton  = UIButton(type: .system)
    private let headerSeparator = UIView()

    private var levelMeterStrip: LevelMeterStripView?
    private var cancellables = Set<AnyCancellable>()
    private var didOfferLaunchTour = false
    private lazy var sessionSaver = SessionSaver { [weak self] in
        guard let self else { return }
        PatternStore.saveSession(self.store.sessionState())
    }
    private lazy var exportCoordinator = ExportCoordinator(engine: engine, store: store, toast: toast)

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        configureBody()
        bindEngine()
        bindStore()
        prepareAudio()
        loadInitialPreset()
        exportCoordinator.presenter = self
        exportCoordinator.popoverSourceView = moreButton
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(replayLaunchTourRequested),
                                               name: .replayLaunchTourRequested,
                                               object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        offerLaunchTourIfNeeded()
    }

    @objc private func appDidEnterBackground() {
        engine.handleAppBackgrounded()
    }

    // Edits made inside the save debounce window must not be lost to suspension.
    @objc private func appWillResignActive() {
        sessionSaver.flush()
    }

    private func offerLaunchTourIfNeeded() {
        guard !didOfferLaunchTour, !AppSettings.hasHandledLaunchTourIntro, presentedViewController == nil else { return }
        didOfferLaunchTour = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            self.presentLaunchTourPrompt()
        }
    }

    @objc private func replayLaunchTourRequested() {
        dismiss(animated: true) { [weak self] in
            self?.presentLaunchTour()
        }
    }

    private func presentLaunchTourPrompt() {
        let alert = UIAlertController(
            title: "Take a quick tour?",
            message: "See the basics in under a minute, or jump straight in.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            AppSettings.hasHandledLaunchTourIntro = true
        })
        alert.addAction(UIAlertAction(title: "Start Tour", style: .default) { [weak self] _ in
            self?.presentLaunchTour()
        })
        alert.preferredAction = alert.actions.last
        present(alert, animated: true)
    }

    private func presentLaunchTour() {
        view.layoutIfNeeded()
        let steps = [
            TourStep(
                title: "Start the groove",
                message: "Press Play to start the loop. Tap BPM to adjust tempo and swing.",
                padding: UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6),
                targetFrame: { [weak self] in self?.transportControlsTourFrame() ?? .zero }
            ),
            TourStep(
                title: "Build the beat",
                message: "Tap cells to turn steps on and off. The bright columns mark the downbeats.",
                targetFrame: { [weak self] in self?.stepGridTourFrame() ?? .zero }
            ),
            TourStep(
                title: "Long-press a step",
                message: "Hold an active step to edit accents. Melodic tracks also include pitch choices.",
                padding: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
                targetFrame: { [weak self] in self?.longPressStepTourFrame() ?? .zero }
            ),
            TourStep(
                title: "Shape each track",
                message: "Tap a track name for preview, randomize, shift, and clear actions. Tap volume for level, pan, pitch, reverb, delay, and distortion.",
                padding: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6),
                targetFrame: { [weak self] in self?.trackControlTourFrame() ?? .zero }
            ),
            TourStep(
                title: "Swap kits and mixes",
                message: "Try different sound kits, load built-in mixes, or save your own.",
                padding: UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6),
                targetFrame: { [weak self] in self?.libraryControlsTourFrame() ?? .zero }
            ),
        ]
        let tour = TourOverlayViewController(steps: steps)
        tour.onFinish = {
            AppSettings.hasHandledLaunchTourIntro = true
        }
        present(tour, animated: true)
    }

    private func transportControlsTourFrame() -> CGRect {
        transportView.superview?.layoutIfNeeded()
        return transportView.convert(transportView.playTempoTourFrame, to: view)
    }

    private func stepGridTourFrame() -> CGRect {
        let frame = sequencerView.frame
        let headerWidth: CGFloat = 154
        let headerHeight: CGFloat = 28
        return CGRect(
            x: frame.minX + headerWidth,
            y: frame.minY + headerHeight,
            width: max(120, frame.width - headerWidth),
            height: max(80, frame.height - headerHeight)
        )
    }

    private func longPressStepTourFrame() -> CGRect {
        sequencerView.layoutIfNeeded()
        if let cellFrame = sequencerView.tourFrameForCell(trackIndex: 0, step: 0) {
            return sequencerView.convert(cellFrame, to: view)
        }
        let grid = stepGridTourFrame()
        let rowHeight = max(48, grid.height / CGFloat(max(1, Tracks.all.count)))
        return CGRect(x: grid.minX, y: grid.minY, width: rowHeight, height: rowHeight)
    }

    private func trackControlTourFrame() -> CGRect {
        let grid = sequencerView.frame
        let rowHeight = max(40, (grid.height - 28) / CGFloat(max(1, Tracks.all.count)))
        return CGRect(x: grid.minX, y: grid.minY + 28, width: 150, height: rowHeight * 2 + 4)
    }

    private func libraryControlsTourFrame() -> CGRect {
        kitsButton.superview?.layoutIfNeeded()
        let kitsFrame = kitsButton.frame
        let mixesFrame = patternsButton.frame
        let settingsFrame = settingsButton.frame
        return kitsFrame.union(mixesFrame).union(settingsFrame)
    }

    private func prepareAudio() {
        do { try engine.prepare() }
        catch {
            toast.show("Audio engine failed to start — playback and export are disabled. Try restarting the app.",
                       tone: .warn)
        }
        transportView.setPlayEnabled(engine.isReady)
    }

    private func loadInitialPreset() {
        if let session = PatternStore.loadSession() {
            store.loadSession(session)
        } else if let preset = Presets.all.first(where: { $0.id == "boom-bap-classic" }) ?? Presets.all.first(where: { $0.id != "empty" }) {
            store.loadPattern(preset)
        }
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        engine.reloadKit(store.currentKitId)
    }

    private func applyTrackVolumesToEngine() {
        for (id, v) in store.volumes(for: currentEngineBar) { engine.setTrackGain(id, v) }
        engine.setMasterGain(store.masterGain)
    }

    private func applyTrackEffectsToEngine() {
        for (id, fx) in store.effects(for: currentEngineBar) { engine.setTrackEffects(id, fx) }
    }

    private var currentEngineBar: Int {
        guard store.patternLength == 32, store.activeStep >= 16 else { return 0 }
        return 1
    }

    // MARK: - Layout

    private func configureBody() {
        // ── Library button ────────────────────────────────────────────────
        patternsButton.configuration = headerButtonConfig(title: "Mixes")
        patternsButton.addTarget(self, action: #selector(showLibrary), for: .touchUpInside)
        patternsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patternsButton)

        // ── Kits button ───────────────────────────────────────────────────
        kitsButton.configuration = headerButtonConfig(title: "Kits")
        kitsButton.addTarget(self, action: #selector(showKitPicker), for: .touchUpInside)
        kitsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kitsButton)

        // ── Save button ─────────────────────────────────────────────────────
        undoButton.configuration = headerIconButtonConfig(systemName: "arrow.uturn.backward")
        undoButton.accessibilityLabel = "Undo"
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(undoButton)

        // ── ••• menu button ───────────────────────────────────────────────
        moreButton.configuration = headerIconButtonConfig(systemName: "rectangle.split.2x1")
        moreButton.accessibilityLabel = "Bar Actions"
        moreButton.addTarget(self, action: #selector(showActionsPanel), for: .touchUpInside)
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moreButton)

        // ── Settings gear button (far right) ──────────────────────────────
        settingsButton.configuration = headerIconButtonConfig(systemName: "gear")
        settingsButton.accessibilityLabel = "Settings"
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)

        // ── Transport ─────────────────────────────────────────────────────
        transportView.delegate = self
        transportView.observe(store)
        transportView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transportView)

        // ── Header separator ──────────────────────────────────────────────
        headerSeparator.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        headerSeparator.isUserInteractionEnabled = false
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerSeparator)

        // ── Sequencer ─────────────────────────────────────────────────────
        sequencerView.delegate = self
        sequencerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sequencerView)

        // ── Constraints ───────────────────────────────────────────────────
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Right side: ••• → Save → Kits → Mixes → Settings (gear far right)
            settingsButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            settingsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 38),

            patternsButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            patternsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            kitsButton.trailingAnchor.constraint(equalTo: patternsButton.leadingAnchor, constant: -8),
            kitsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            undoButton.trailingAnchor.constraint(equalTo: kitsButton.leadingAnchor, constant: -8),
            undoButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),
            undoButton.widthAnchor.constraint(equalToConstant: 38),

            moreButton.trailingAnchor.constraint(equalTo: undoButton.leadingAnchor, constant: -8),
            moreButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 38),

            // Header separator — centered in the 8pt gap between header and grid
            headerSeparator.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            headerSeparator.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1),
            headerSeparator.topAnchor.constraint(equalTo: transportView.bottomAnchor, constant: 4),

            // Transport fills from left edge to ••• button
            transportView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            transportView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            transportView.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -10),

            // Sequencer
            sequencerView.topAnchor.constraint(equalTo: transportView.bottomAnchor, constant: 8),
            sequencerView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            sequencerView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            sequencerView.heightAnchor.constraint(lessThanOrEqualTo: sequencerView.widthAnchor,
                                                  multiplier: 0.5, constant: -39),
        ])

        let fillBottom = sequencerView.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8)
        fillBottom.priority = .defaultHigh
        fillBottom.isActive = true

        updateUndoState()

        if UIDevice.current.userInterfaceIdiom == .pad {
            let strip = LevelMeterStripView()
            strip.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(strip)
            NSLayoutConstraint.activate([
                strip.topAnchor.constraint(equalTo: sequencerView.bottomAnchor, constant: 8),
                strip.leadingAnchor.constraint(equalTo: sequencerView.leadingAnchor),
                strip.trailingAnchor.constraint(equalTo: sequencerView.trailingAnchor),
                strip.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            ])
            levelMeterStrip = strip
        }
    }

    private func headerButtonConfig(title: String) -> UIButton.Configuration {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        cfg.baseForegroundColor = Theme.text
        cfg.background.backgroundColor = Theme.backgroundElevated2
        cfg.background.strokeColor = Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        return cfg
    }

    private func headerIconButtonConfig(systemName: String) -> UIButton.Configuration {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: systemName,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        cfg.baseForegroundColor = Theme.textDim
        cfg.background.backgroundColor = Theme.backgroundElevated2
        cfg.background.strokeColor = Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        return cfg
    }

    // MARK: - Bindings

    private func bindEngine() {
        engine.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .started: self?.transportView.setIsPlaying(true)
                case .stopped: self?.transportView.setIsPlaying(false)
                case .step(let s):
                    self?.store.setActiveStep(s)
                    if s >= 0, let strip = self?.levelMeterStrip, let self {
                        for track in Tracks.all where
                            self.store.isStepActive(trackId: track.id, step: s) &&
                            self.store.mutes[track.id] != true {
                            strip.trigger(trackId: track.id)
                        }
                    }
                case .engineFailed:
                    guard let self else { return }
                    self.transportView.setIsPlaying(false)
                    self.store.setActiveStep(-1)
                    // Transient failures (e.g. session busy during a call) keep
                    // isReady true and stay retryable; only a dead graph disables.
                    self.transportView.setPlayEnabled(self.engine.isReady)
                    self.toast.show("Audio engine unavailable — try closing and reopening the app",
                                    tone: .warn)
                }
            }
            .store(in: &cancellables)
    }

    private func bindStore() {
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self else { return }
                if section == .load {
                    self.applyTrackVolumesToEngine()
                    self.applyTrackEffectsToEngine()
                }
                if section == .tempo {
                    if self.engine.isPlaying { self.applyTrackEffectsToEngine() }
                }
                if section == .volumes {
                    if self.engine.isPlaying { self.applyTrackVolumesToEngine() }
                }
                if section == .effects {
                    if self.engine.isPlaying { self.applyTrackEffectsToEngine() }
                }
                if section == .undo || section == .load {
                    self.updateUndoState()
                }
                if section != .step {
                    self.scheduleSessionSave()
                }
            }
            .store(in: &cancellables)
    }

    private func updateUndoState() {
        undoButton.isEnabled = store.canUndo
        undoButton.alpha = store.canUndo ? 1.0 : 0.35
    }

    private func scheduleSessionSave() {
        sessionSaver.schedule()
    }

    // MARK: - TransportViewDelegate

    func transportTogglePlay() {
        guard engine.isReady else {
            toast.show("Audio engine unavailable — try restarting the app", tone: .warn)
            return
        }
        if engine.isPlaying { engine.stop() } else { engine.start() }
    }

    func transportSetTempo(_ value: Double) { store.setTempo(value) }
    func transportSetSwing(_ value: Double) { store.setSwing(value) }
    func transportSetMaster(_ value: Float) {
        store.setMasterGain(value)
        engine.setMasterGain(value)
    }
    func transportDidRequestPatternLength(_ length: Int) {
        sequencerDidRequestPatternLength(length)
    }

    // MARK: - SequencerViewDelegate

    func sequencer(toggleStep trackId: String, step: Int) {
        store.toggleStep(trackId: trackId, step: step)
    }

    func sequencerDidRequestPatternLength(_ length: Int) {
        if length == 32 { handleExpandToTwoBars() } else { handleCollapseToOneBar() }
    }

    func sequencerDidRequestTrackActions(_ track: Track) {
        let panel = TrackActionsViewController(track: track)
        panel.trackHasAccents = store.accents[track.id]?.contains(true) ?? false
        panel.onPreviewSound = { [weak self] in self?.engine.preview(trackId: track.id) }
        panel.onClearTrack = { [weak self] in
            self?.store.clearTrack(trackId: track.id)
            self?.toast.show("\(track.name) cleared", tone: .ok)
        }
        panel.onShiftLeft = { [weak self] in
            self?.store.shiftTrack(trackId: track.id, by: 1)
            self?.toast.show("\(track.name) shifted left", tone: .ok)
        }
        panel.onShiftRight = { [weak self] in
            self?.store.shiftTrack(trackId: track.id, by: -1)
            self?.toast.show("\(track.name) shifted right", tone: .ok)
        }
        panel.onRandomizeTrack = { [weak self] intensity in
            self?.store.randomizeTrack(track.id, intensity: intensity)
            self?.toast.show("\(track.name) randomized: \(intensity.title)", tone: .ok)
        }
        panel.onClearTrackAccents = { [weak self] in
            self?.store.clearTrackAccents(trackId: track.id)
            self?.toast.show("\(track.name) accents cleared", tone: .ok)
        }
        presentWhenReady(panel)
    }

    func sequencerDidToggleAccent(isAccented: Bool) {
        toast.show(isAccented ? "Accent added · louder hit" : "Accent removed", tone: .ok)
    }

    func sequencerDidRequestStepOptions(_ track: Track, step: Int) {
        let accentRow = store.accents[track.id]
        let pitchRow = store.pitches[track.id]
        let panel = StepOptionsViewController(
            track: track, step: step,
            isAccented: accentRow?.indices.contains(step) == true && accentRow![step],
            pitch: pitchRow?.indices.contains(step) == true ? pitchRow![step] : 0)
        // With the transport stopped, audition each change so edits are audible.
        func previewStepIfIdle() {
            guard !engine.isPlaying else { return }
            let pitchRow = store.pitches[track.id]
            let accentRow = store.accents[track.id]
            engine.preview(trackId: track.id,
                           semitones: pitchRow?.indices.contains(step) == true ? pitchRow![step] : 0,
                           accented: accentRow?.indices.contains(step) == true && accentRow![step])
        }
        panel.onSetAccent = { [weak self] accented in
            self?.store.setStepAccent(trackId: track.id, step: step, accented: accented)
            previewStepIfIdle()
        }
        panel.onSetPitch = { [weak self] semitones in
            self?.store.setStepPitch(trackId: track.id, step: step, semitones: semitones)
            previewStepIfIdle()
        }
        presentWhenReady(panel)
    }

    func sequencerDidRequestBarActions(barIndex: Int) {
        let panel = BarActionsViewController(barIndex: barIndex)
        panel.onClearBar = { [weak self] in
            self?.store.clearBar(barIndex)
            self?.toast.show("Bar \(barIndex + 1) cleared", tone: .ok)
        }
        panel.onRandomizeBar = { [weak self] intensity in
            self?.store.randomizeBar(barIndex, intensity: intensity)
            self?.toast.show("Bar \(barIndex + 1) randomized: \(intensity.title)", tone: .ok)
        }
        panel.onHumanizeBar = { [weak self] in
            self?.store.humanizeBar(barIndex)
            self?.toast.show("Bar \(barIndex + 1) mutated", tone: .ok)
        }
        panel.onAccentBar = { [weak self] pattern in
            self?.store.accentBar(barIndex, pattern: pattern)
            self?.toast.show("Bar \(barIndex + 1) \(pattern.title.lowercased()) accented", tone: .ok)
        }
        panel.onClearBarAccents = { [weak self] in
            self?.store.clearBarAccents(barIndex)
            self?.toast.show("Bar \(barIndex + 1) accents cleared", tone: .ok)
        }
        panel.onDuplicateToBar2 = { [weak self] in self?.copyBar1ToBar2() }
        panel.onGenerateBar2Variation = { [weak self] in self?.generateBar2Variation() }
        panel.onCopyBar1Here = { [weak self] in self?.copyBar1ToBar2() }
        presentWhenReady(panel)
    }

    private func handleExpandToTwoBars() {
        guard store.patternLength == 16 else { return }

        // If 32-step rows are already preserved in memory, restore them silently.
        if store.hasPreservedBar2 {
            store.setPatternLength(32)
            return
        }

        // Find the matching built-in 2-bar preset variant
        let matchingPreset = Presets.all.first {
            $0.basePresetId == store.currentPatternId && ($0.barLength ?? 1) == 2
        }

        let sheet = UIAlertController(title: "Add Second Bar", message: nil, preferredStyle: .actionSheet)

        if store.isDirty {
            sheet.addAction(UIAlertAction(title: "Duplicate Current Bar 1", style: .default) { [weak self] _ in
                self?.expandDuplicate()
            })
            sheet.addAction(UIAlertAction(title: "Generate Bar 2 Variation", style: .default) { [weak self] _ in
                self?.expandVariation()
            })
            sheet.addAction(UIAlertAction(title: "Start with Blank Bar 2", style: .default) { [weak self] _ in
                self?.store.setPatternLength(32)
            })
        } else {
            if let preset = matchingPreset {
                sheet.addAction(UIAlertAction(title: "Use Matching 2-Bar Preset", style: .default) { [weak self] _ in
                    self?.doLoadPattern(preset)
                })
            }
            sheet.addAction(UIAlertAction(title: "Duplicate Bar 1", style: .default) { [weak self] _ in
                self?.expandDuplicate()
            })
            sheet.addAction(UIAlertAction(title: "Generate Bar 2 Variation", style: .default) { [weak self] _ in
                self?.expandVariation()
            })
            sheet.addAction(UIAlertAction(title: "Start with Blank Bar 2", style: .default) { [weak self] _ in
                self?.store.setPatternLength(32)
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = transportView.patternLengthButton
        sheet.popoverPresentationController?.sourceRect = transportView.patternLengthButton.bounds

        presentWhenReady(sheet)
    }

    private func expandDuplicate() {
        store.expandToTwoBarsDuplicate()
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
    }

    private func expandVariation() {
        store.generateBar2Variation()
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        toast.show("Bar 2 variation generated", tone: .ok)
    }

    private func handleCollapseToOneBar() {
        guard store.patternLength == 32 else { return }
        if store.hasBar2Content {
            let alert = UIAlertController(
                title: "Switch to 1 Bar?",
                message: "Bar 2 will be hidden. Switch back to 2 Bars anytime to restore it.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Keep 2 Bars", style: .cancel))
            alert.addAction(UIAlertAction(title: "Switch to 1 Bar", style: .default) { [weak self] _ in
                self?.store.setPatternLength(16)
            })
            presentWhenReady(alert)
        } else {
            store.setPatternLength(16)
        }
    }

    // Waits for any in-flight dismissal to complete before presenting, so we never
    // call present while a previous sheet's dismiss animation is still running.
    private func presentWhenReady(_ vc: UIViewController, attempt: Int = 0) {
        guard attempt < 10 else { return }
        if presentedViewController != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.presentWhenReady(vc, attempt: attempt + 1)
            }
        } else {
            present(vc, animated: true)
        }
    }

    private func copyBar1ToBar2() {
        guard store.hasBar2Content else {
            store.duplicateBar1()
            toast.show("Bar 1 copied to Bar 2", tone: .ok)
            return
        }
        let alert = UIAlertController(
            title: "Overwrite Bar 2?",
            message: "Bar 2 has steps. This will replace them with Bar 1.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Copy", style: .destructive) { [weak self] _ in
            self?.store.duplicateBar1()
            self?.toast.show("Bar 1 copied to Bar 2", tone: .ok)
        })
        present(alert, animated: true)
    }

    private func generateBar2Variation() {
        guard store.hasBar2Content else {
            expandVariation()
            return
        }
        let alert = UIAlertController(
            title: "Overwrite Bar 2?",
            message: "Bar 2 has steps. This will replace them with a variation of Bar 1.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Generate Variation", style: .destructive) { [weak self] _ in
            self?.expandVariation()
        })
        present(alert, animated: true)
    }

    // MARK: - Pattern library

    @objc private func showSettings() {
        let settings = SettingsViewController()
        settings.modalPresentationStyle = .pageSheet
        if let sheet = settings.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(settings, animated: true)
    }

    @objc private func showActionsPanel() {
        if AppSettings.hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        let panel = ActionsViewController()
        panel.patternLength = store.patternLength
        panel.currentBar = sequencerView.currentBar
        panel.onSaveMix = { [weak self] in self?.promptSave(sourceView: self?.moreButton, completion: nil) }
        panel.onClearBar = { [weak self] barIndex in
            self?.store.clearBar(barIndex)
            self?.toast.show("Bar \(barIndex + 1) cleared", tone: .ok)
        }
        panel.onExportWAV = { [weak self] in self?.exportCoordinator.requestExport(format: .wav) }
        panel.onExportM4A = { [weak self] in self?.exportCoordinator.requestExport(format: .m4a) }
        // copyBar1ToBar2 owns its own feedback (including the overwrite-cancel path).
        panel.onCopyBar1ToBar2 = { [weak self] in self?.copyBar1ToBar2() }
        presentWhenReady(panel)
    }

    @objc private func showKitPicker() {
        if AppSettings.hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        let picker = KitPickerViewController(currentKitId: store.currentKitId)
        picker.onSelect = { [weak self] kit in
            guard let self else { return }
            self.store.setKit(kit.id)
            self.engine.reloadKit(kit.id)
            self.toast.show("Kit: \(kit.name)", tone: .ok)
        }
        present(picker, animated: true)
    }

    @objc private func showLibrary() {
        if AppSettings.hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        let lib = PatternLibraryViewController(currentName: store.patternName, currentPatternId: store.currentPatternId, currentKitId: store.currentKitId)
        lib.delegate = self
        present(lib, animated: true)
    }

    func patternLibraryDidPick(_ pattern: Pattern) {
        guard store.isDirty else { doLoadPattern(pattern); return }
        let alert = UIAlertController(title: "Unsaved Changes",
                                      message: "Switch patterns and lose changes to \"\(store.patternName)\"?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Switch Anyway", style: .destructive) { [weak self] _ in
            self?.doLoadPattern(pattern)
        })
        present(alert, animated: true)
    }

    func patternLibraryDidRequestSaveMix() {
        promptSave(sourceView: patternsButton, completion: nil)
    }

    private func doLoadPattern(_ pattern: Pattern) {
        let wasPlaying = engine.isPlaying
        if wasPlaying { engine.stop() }
        store.loadPattern(pattern)
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        engine.reloadKit(store.currentKitId)
        if wasPlaying { engine.start() }
        toast.show("Loaded \"\(pattern.name)\"", tone: .ok)
    }

    @objc private func undoTapped() {
        if AppSettings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        store.undo()
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        engine.reloadKit(store.currentKitId)
    }

    private func promptSave(sourceView: UIView? = nil, completion: ((Bool) -> Void)?) {
        if store.isCurrentPatternUserSaved {
            let name = store.patternName
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Update \"\(name)\"", style: .default) { [weak self] _ in
                self?.doUpdatePattern(completion: completion)
            })
            sheet.addAction(UIAlertAction(title: "Save as New…", style: .default) { [weak self] _ in
                guard let self else { return }
                self.promptSaveAsNew(suggestedName: PatternStore.uniqueName("\(self.store.patternName) Copy"), completion: completion)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion?(false) })
            sheet.popoverPresentationController?.sourceView = sourceView ?? moreButton
            present(sheet, animated: true)
        } else if store.isCurrentPatternPreset {
            promptSaveAsNew(title: "Save as New",
                            suggestedName: PatternStore.uniqueName(store.patternName),
                            saveButtonTitle: "Save New",
                            completion: completion)
        } else {
            promptSaveAsNew(completion: completion)
        }
    }

    private func doUpdatePattern(completion: ((Bool) -> Void)?) {
        var pattern = store.exportPattern()
        pattern.id = store.currentPatternId
        if PatternStore.save(pattern) {
            store.markClean()
            toast.show("Updated \"\(pattern.name)\"", tone: .ok)
            completion?(true)
        } else {
            toast.show("Could not save mix", tone: .warn)
            completion?(false)
        }
    }

    private func promptSaveAsNew(title: String = "Save Mix",
                                 suggestedName: String? = nil,
                                 saveButtonTitle: String = "Save",
                                 completion: ((Bool) -> Void)?) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Mix name"
            tf.text = suggestedName ?? (self.store.patternName == "Untitled" ? "" : self.store.patternName)
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion?(false) })
        alert.addAction(UIAlertAction(title: saveButtonTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { completion?(false); return }
            // Auto-suffix so a new mix can never shadow an existing one.
            let name = PatternStore.uniqueName(raw)
            var pattern = self.store.exportPattern()
            pattern.name = name
            if PatternStore.save(pattern) {
                self.store.setPatternName(name)
                self.store.setCurrentPatternId(pattern.id)
                self.store.markClean()
                self.toast.show("Saved \"\(name)\"", tone: .ok)
                completion?(true)
            } else {
                self.toast.show("Could not save pattern", tone: .warn)
                completion?(false)
            }
        })
        present(alert, animated: true)
    }
}
