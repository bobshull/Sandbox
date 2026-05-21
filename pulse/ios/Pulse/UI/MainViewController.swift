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
    private let moreButton      = UIButton(type: .system)
    private let headerSeparator = UIView()

    private var levelMeterStrip: LevelMeterStripView?
    private var cancellables = Set<AnyCancellable>()
    private var saveWork: DispatchWorkItem?

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
    }

    private func prepareAudio() {
        do { try engine.prepare() }
        catch { toast.show("Audio engine failed to start", tone: .warn) }
    }

    private func loadInitialPreset() {
        if let session = PatternStore.loadSession() {
            store.loadSession(session)
        } else if let preset = Presets.all.first(where: { $0.id != "empty" }) {
            store.loadPattern(preset)
        }
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        engine.reloadKit(store.currentKitId)
    }

    private func applyTrackVolumesToEngine() {
        for (id, v) in store.volumes { engine.setTrackGain(id, v) }
        engine.setMasterGain(store.masterGain)
    }

    private func applyTrackEffectsToEngine() {
        for (id, fx) in store.effects { engine.setTrackEffects(id, fx) }
    }

    // MARK: - Layout

    private func configureBody() {
        // ── Library button ────────────────────────────────────────────────
        patternsButton.configuration = headerButtonConfig(title: "Library")
        patternsButton.addTarget(self, action: #selector(showLibrary), for: .touchUpInside)
        patternsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patternsButton)

        // ── Kits button ───────────────────────────────────────────────────
        kitsButton.configuration = headerButtonConfig(title: "Kits")
        kitsButton.addTarget(self, action: #selector(showKitPicker), for: .touchUpInside)
        kitsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kitsButton)

        // ── ••• menu button ───────────────────────────────────────────────
        var moreCfg = UIButton.Configuration.plain()
        moreCfg.image = UIImage(systemName: "ellipsis",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        moreCfg.baseForegroundColor = Theme.textDim
        moreCfg.background.backgroundColor = Theme.backgroundElevated2
        moreCfg.background.strokeColor = Theme.border
        moreCfg.background.strokeWidth = 1
        moreCfg.background.cornerRadius = 6
        moreCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        moreButton.configuration = moreCfg
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else { completion([]); return }
                let save = UIAction(title: "Save Mix",
                                    image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                    self?.quickSaveTapped()
                }
                let undo = UIAction(title: "Undo",
                                    image: UIImage(systemName: "arrow.uturn.backward"),
                                    attributes: self.store.canUndo ? [] : .disabled) { [weak self] _ in
                    self?.undoTapped()
                }
                let export = UIAction(title: "Export",
                                      image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    self?.exportTapped()
                }
                var items: [UIMenuElement] = [save, undo, export]
                if self.store.patternLength == 32 {
                    let copy = UIAction(title: "Copy Bar 1 to Bar 2",
                                        image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                        self?.copyBar1ToBar2()
                    }
                    items.append(copy)
                }
                completion(items)
            }
        ])
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moreButton)

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
            // Right side: Library → Kits → ••• (fixed, no responsive swap)
            patternsButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            patternsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            kitsButton.trailingAnchor.constraint(equalTo: patternsButton.leadingAnchor, constant: -8),
            kitsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            moreButton.trailingAnchor.constraint(equalTo: kitsButton.leadingAnchor, constant: -8),
            moreButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),
            moreButton.heightAnchor.constraint(equalToConstant: 38),

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
                            self.store.rows[track.id]?[s] == true &&
                            self.store.mutes[track.id] != true {
                            strip.trigger(trackId: track.id)
                        }
                    }
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
                    self.engine.updateDelayTimes(tempo: self.store.tempo)
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
        // moreButton menu rebuilds fresh via UIDeferredMenuElement.uncached — nothing else to update
    }

    private func scheduleSessionSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            PatternStore.saveSession(self.store.sessionState())
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - TransportViewDelegate

    func transportTogglePlay() {
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
            sheet.addAction(UIAlertAction(title: "Start with Blank Bar 2", style: .default) { [weak self] _ in
                self?.store.setPatternLength(32)
            })
            if let preset = matchingPreset {
                sheet.addAction(UIAlertAction(
                    title: "Load \"\(preset.name)\" 2-Bar — replaces unsaved changes",
                    style: .destructive) { [weak self] _ in
                    self?.doLoadPattern(preset)
                })
            }
        } else {
            if let preset = matchingPreset {
                sheet.addAction(UIAlertAction(title: "Use Matching 2-Bar Preset", style: .default) { [weak self] _ in
                    self?.doLoadPattern(preset)
                })
            }
            sheet.addAction(UIAlertAction(title: "Duplicate Bar 1", style: .default) { [weak self] _ in
                self?.expandDuplicate()
            })
            sheet.addAction(UIAlertAction(title: "Start with Blank Bar 2", style: .default) { [weak self] _ in
                self?.store.setPatternLength(32)
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = transportView
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: transportView.bounds.midX, y: transportView.bounds.minY, width: 0, height: 0)

        presentWhenReady(sheet)
    }

    private func expandDuplicate() {
        store.expandToTwoBarsDuplicate()
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
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
        let bar2HasContent = store.rows.values.contains { arr in
            arr.count == 32 && arr[16...].contains(true)
        }
        guard bar2HasContent else {
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

    // MARK: - Pattern library

    @objc private func showKitPicker() {
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.undo()
        applyTrackVolumesToEngine()
        applyTrackEffectsToEngine()
        engine.reloadKit(store.currentKitId)
    }

    @objc private func quickSaveTapped() { promptSave(completion: nil) }

    @objc private func exportTapped() {
        let sheet = UIAlertController(title: "Export Mix", message: nil, preferredStyle: .actionSheet)
        let labels = ["Short Loop", "Medium Loop", "Long Loop", "Extended Loop"]
        for (i, bars) in [4, 8, 16, 32].enumerated() {
            let secs = Int(Double(bars) * 4.0 * 60.0 / store.tempo)
            sheet.addAction(UIAlertAction(title: "\(labels[i])  —  ~\(secs)s", style: .default) { [weak self] _ in
                self?.runExport(bars: bars)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = moreButton
        present(sheet, animated: true)
    }

    private func runExport(bars: Int) {
        let progress = UIAlertController(title: "Exporting…", message: nil, preferredStyle: .alert)
        present(progress, animated: true)
        engine.exportMix(bars: bars) { [weak self] result in
            guard let self else { return }
            progress.dismiss(animated: true) {
                switch result {
                case .success(let url):
                    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    share.popoverPresentationController?.sourceView = self.moreButton
                    self.present(share, animated: true)
                case .failure(let err):
                    self.toast.show("Export failed: \(err.localizedDescription)", tone: .warn)
                }
            }
        }
    }

    private func promptSave(completion: ((Bool) -> Void)?) {
        if store.isCurrentPatternUserSaved {
            let name = store.patternName
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Update \"\(name)\"", style: .default) { [weak self] _ in
                self?.doUpdatePattern(completion: completion)
            })
            sheet.addAction(UIAlertAction(title: "Save as New…", style: .default) { [weak self] _ in
                self?.promptSaveAsNew(completion: completion)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion?(false) })
            sheet.popoverPresentationController?.sourceView = moreButton
            present(sheet, animated: true)
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
            toast.show("Could not save pattern", tone: .warn)
            completion?(false)
        }
    }

    private func promptSaveAsNew(completion: ((Bool) -> Void)?) {
        let alert = UIAlertController(title: "Save Pattern", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Pattern name"
            tf.text = self.store.patternName == "Untitled" ? "" : self.store.patternName
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion?(false) })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { completion?(false); return }
            var pattern = self.store.exportPattern()
            pattern.name = raw
            if PatternStore.save(pattern) {
                self.store.setPatternName(raw)
                self.store.setCurrentPatternId(pattern.id)
                self.store.markClean()
                self.toast.show("Saved \"\(raw)\"", tone: .ok)
                completion?(true)
            } else {
                self.toast.show("Could not save pattern", tone: .warn)
                completion?(false)
            }
        })
        present(alert, animated: true)
    }
}
