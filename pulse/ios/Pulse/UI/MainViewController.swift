import UIKit
import Combine

final class MainViewController: UIViewController, TransportViewDelegate, SequencerViewDelegate,
                                PatternLibraryDelegate {

    private let store = Store()
    private lazy var engine = AudioEngine(store: store)

    private lazy var transportView = TransportView(store: store)
    private lazy var sequencerView = SequencerView(store: store, engine: engine)
    private lazy var toast = ToastPresenter(host: view)

    private let patternsButton = UIButton(type: .system)
    private let kitsButton = UIButton(type: .system)
    private let quickSaveButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
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
        do {
            try engine.prepare()
        } catch {
            toast.show("Audio engine failed to start", tone: .warn)
            print("[Pulse] audio prepare failed: \(error)")
        }
    }

    private func loadInitialPreset() {
        if let session = PatternStore.loadSession() {
            store.loadSession(session)
        } else if let preset = Presets.all.first(where: { $0.id == "floor-filler" }) {
            store.loadPattern(preset)
        }
        applyTrackVolumesToEngine()
        engine.reloadKit(store.currentKitId)
    }

    private func applyTrackVolumesToEngine() {
        for (id, v) in store.volumes { engine.setTrackGain(id, v) }
        engine.setMasterGain(store.masterGain)
    }

    // MARK: - Layout

    private func configureBody() {
        var cfg = UIButton.Configuration.plain()
        cfg.title = "Library"
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        cfg.baseForegroundColor = Theme.text
        cfg.background.backgroundColor = Theme.backgroundElevated2
        cfg.background.strokeColor = Theme.border
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        patternsButton.configuration = cfg
        patternsButton.addTarget(self, action: #selector(showLibrary), for: .touchUpInside)
        patternsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patternsButton)

        var kitsCfg = UIButton.Configuration.plain()
        kitsCfg.title = "Kits"
        kitsCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = .systemFont(ofSize: 13, weight: .semibold); return out
        }
        kitsCfg.baseForegroundColor = Theme.text
        kitsCfg.background.backgroundColor = Theme.backgroundElevated2
        kitsCfg.background.strokeColor = Theme.border
        kitsCfg.background.strokeWidth = 1
        kitsCfg.background.cornerRadius = 6
        kitsCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        kitsButton.configuration = kitsCfg
        kitsButton.addTarget(self, action: #selector(showKitPicker), for: .touchUpInside)
        kitsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kitsButton)

        var saveCfg = UIButton.Configuration.plain()
        saveCfg.image = UIImage(systemName: "plus.circle",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        saveCfg.baseForegroundColor = Theme.text
        saveCfg.background.backgroundColor = Theme.backgroundElevated2
        saveCfg.background.strokeColor = Theme.border
        saveCfg.background.strokeWidth = 1
        saveCfg.background.cornerRadius = 6
        saveCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        quickSaveButton.configuration = saveCfg
        quickSaveButton.addTarget(self, action: #selector(quickSaveTapped), for: .touchUpInside)
        quickSaveButton.accessibilityLabel = "Save pattern"
        quickSaveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(quickSaveButton)

        var undoCfg = UIButton.Configuration.plain()
        undoCfg.image = UIImage(systemName: "arrow.uturn.backward",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        undoCfg.baseForegroundColor = Theme.textFaint
        undoCfg.background.backgroundColor = Theme.backgroundElevated2
        undoCfg.background.strokeColor = Theme.border
        undoCfg.background.strokeWidth = 1
        undoCfg.background.cornerRadius = 6
        undoCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        undoButton.configuration = undoCfg
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        undoButton.accessibilityLabel = "Undo"
        undoButton.isEnabled = false
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(undoButton)

        var exportCfg = UIButton.Configuration.plain()
        exportCfg.image = UIImage(systemName: "square.and.arrow.up",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        exportCfg.baseForegroundColor = Theme.textDim
        exportCfg.background.backgroundColor = Theme.backgroundElevated2
        exportCfg.background.strokeColor = Theme.border
        exportCfg.background.strokeWidth = 1
        exportCfg.background.cornerRadius = 6
        exportCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        exportButton.configuration = exportCfg
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        exportButton.accessibilityLabel = "Export mix"
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)

        transportView.delegate = self
        transportView.observe(store)
        transportView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transportView)

        sequencerView.delegate = self
        sequencerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sequencerView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            patternsButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            patternsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            kitsButton.trailingAnchor.constraint(equalTo: patternsButton.leadingAnchor, constant: -8),
            kitsButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            quickSaveButton.trailingAnchor.constraint(equalTo: kitsButton.leadingAnchor, constant: -8),
            quickSaveButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            undoButton.trailingAnchor.constraint(equalTo: quickSaveButton.leadingAnchor, constant: -6),
            undoButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: undoButton.leadingAnchor, constant: -6),
            exportButton.centerYAnchor.constraint(equalTo: transportView.centerYAnchor),

            transportView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            transportView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            transportView.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -10),

            sequencerView.topAnchor.constraint(equalTo: transportView.bottomAnchor, constant: 8),
            sequencerView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            sequencerView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            // Cap height so cells stay square: derived from cell width formula
            // cellWidth = (seqW - headerCol(150) - gap(4) - beatGaps(24)) / 16 = (W-178)/16
            // squareHeight = header(18) + gap(4) + 8*cellWidth + 7*rowSpacing(4) = 0.5W - 39
            sequencerView.heightAnchor.constraint(lessThanOrEqualTo: sequencerView.widthAnchor,
                                                  multiplier: 0.5, constant: -39),
        ])

        // High-priority fill-to-bottom: wins on iPhone (formula > available),
        // yields on iPad (formula < available, capped by the required constraint above).
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
                }
                if section == .undo || section == .load {
                    self.updateUndoButton()
                }
                if section != .step {
                    self.scheduleSessionSave()
                }
            }
            .store(in: &cancellables)
    }

    private func updateUndoButton() {
        let canUndo = store.canUndo
        undoButton.isEnabled = canUndo
        var cfg = undoButton.configuration ?? UIButton.Configuration.plain()
        cfg.baseForegroundColor = canUndo ? Theme.text : Theme.textFaint
        undoButton.configuration = cfg
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

    func transportSetTempo(_ value: Double) {
        store.setTempo(value)
    }

    func transportSetSwing(_ value: Double) {
        store.setSwing(value)
    }

    func transportSetMaster(_ value: Float) {
        store.setMasterGain(value)
        engine.setMasterGain(value)
    }

    // MARK: - SequencerViewDelegate

    func sequencer(toggleStep trackId: String, step: Int) {
        store.toggleStep(trackId: trackId, step: step)
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
        let lib = PatternLibraryViewController(currentName: store.patternName, currentKitId: store.currentKitId)
        lib.delegate = self
        present(lib, animated: true)
    }

    func patternLibraryDidPick(_ pattern: Pattern) {
        guard store.isDirty else {
            doLoadPattern(pattern); return
        }
        let alert = UIAlertController(
            title: "Unsaved Changes",
            message: "Switch patterns and lose changes to \"\(store.patternName)\"?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Switch Anyway", style: .destructive) { [weak self] _ in
            self?.doLoadPattern(pattern)
        })
        present(alert, animated: true)
    }

    private func doLoadPattern(_ pattern: Pattern) {
        store.loadPattern(pattern)
        applyTrackVolumesToEngine()
        engine.reloadKit(store.currentKitId)
        toast.show("Loaded \"\(pattern.name)\"", tone: .ok)
    }

    @objc private func undoTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.undo()
        applyTrackVolumesToEngine()
        engine.reloadKit(store.currentKitId)
    }

    @objc private func quickSaveTapped() { promptSave(completion: nil) }

    @objc private func exportTapped() {
        let sheet = UIAlertController(title: "Export Mix", message: nil, preferredStyle: .actionSheet)
        let labels = ["Short Loop", "Medium Loop", "Long Loop", "Extended Loop"]
        for (i, bars) in [4, 8, 16, 32].enumerated() {
            let secs = Int(Double(bars) * 4.0 * 60.0 / store.tempo)
            sheet.addAction(UIAlertAction(title: "\(labels[i])  —  \(bars) bars / ~\(secs)s", style: .default) { [weak self] _ in
                self?.runExport(bars: bars)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = exportButton
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
                    share.popoverPresentationController?.sourceView = self.exportButton
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
            sheet.popoverPresentationController?.sourceView = quickSaveButton
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
