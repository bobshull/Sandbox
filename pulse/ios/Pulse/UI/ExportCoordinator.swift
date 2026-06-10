import UIKit

/// Owns the UI and lifecycle side of exporting a mix: readiness checks, the
/// empty-mix warning, the loop picker, the progress alert with cancellation,
/// the UIApplication background task, share-sheet presentation, temp-file
/// cleanup, and user feedback. Audio rendering stays in AudioEngine.exportMix;
/// this type never touches buffers or timing.
final class ExportCoordinator {

    weak var presenter: UIViewController?
    /// Anchor for iPad popovers (action sheets, share sheet).
    weak var popoverSourceView: UIView?

    private let engine: AudioEngine
    private let store: Store
    private let toast: ToastPresenter

    private var currentExport: AudioEngine.ExportHandle?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var interrupted = false

    init(engine: AudioEngine, store: Store, toast: ToastPresenter) {
        self.engine = engine
        self.store = store
        self.toast = toast
    }

    // MARK: - Entry points

    func requestExport(format: ExportFormat) {
        guard let presenter else { return }
        guard engine.isReady else {
            toast.show("Audio engine unavailable — exporting is disabled. Try restarting the app.",
                       tone: .warn)
            return
        }
        guard store.sequenceHasAudibleSteps else {
            let alert = UIAlertController(
                title: "Empty Mix",
                message: "This mix appears to be empty. Export anyway?",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Export Anyway", style: .default) { [weak self] _ in
                self?.presentLoopPicker(format: format)
            })
            presenter.present(alert, animated: true)
            return
        }
        presentLoopPicker(format: format)
    }

    func cancelExport() {
        currentExport?.cancel()
    }

    // MARK: - Loop picker

    private func presentLoopPicker(format: ExportFormat) {
        guard let presenter else { return }
        let title = format == .wav ? "Export WAV" : "Export M4A"
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        let stepDur = 60.0 / store.tempo / 4.0
        for reps in [1, 2, 4, 8] {
            let secs = Int(Double(reps * store.sequenceLength) * stepDur)
            let label = reps == 1 ? "1 Loop" : "\(reps) Loops"
            sheet.addAction(UIAlertAction(title: "\(label)  —  ~\(secs)s", style: .default) { [weak self] _ in
                self?.startExport(reps: reps, format: format)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = popoverSourceView ?? presenter.view
        presenter.present(sheet, animated: true)
    }

    // MARK: - Export run

    private func startExport(reps: Int, format: ExportFormat) {
        guard currentExport == nil, let presenter else { return }
        interrupted = false

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "pulse.export") { [weak self] in
            // iOS is about to suspend us — stop cleanly; the completion handler reports it.
            self?.interrupted = true
            self?.currentExport?.cancel()
            self?.endBackgroundTask()
        }

        let progress = UIAlertController(title: "Exporting…", message: nil, preferredStyle: .alert)
        progress.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.currentExport?.cancel()
        })
        presenter.present(progress, animated: true)

        currentExport = engine.exportMix(reps: reps, format: format) { [weak self] result in
            guard let self else { return }
            let wasCancelled = self.currentExport?.isCancelled == true
            self.currentExport = nil
            self.endBackgroundTask()

            switch result {
            case .success(let url):
                // Cancel can land after the renderer's final check; honor it here.
                guard !wasCancelled else {
                    try? FileManager.default.removeItem(at: url)
                    self.showOutcome(after: progress) {
                        self.toast.show(self.interrupted ? "Export interrupted" : "Export cancelled",
                                        tone: .warn)
                    }
                    return
                }
                self.showOutcome(after: progress) {
                    self.presentShareSheet(for: url)
                }
            case .failure(let err):
                self.showOutcome(after: progress) {
                    if (err as? ExportError) == .cancelled {
                        self.toast.show(self.interrupted ? "Export interrupted" : "Export cancelled",
                                        tone: .warn)
                    } else {
                        self.toast.show("Export failed: \(err.localizedDescription)", tone: .warn)
                    }
                }
            }
        }
    }

    private func presentShareSheet(for url: URL) {
        guard let presenter else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = popoverSourceView ?? presenter.view
        share.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
        }
        presenter.present(share, animated: true)
    }

    /// Dismisses the progress alert if it is still up, then runs `outcome`. The
    /// Cancel action dismisses the alert itself, in which case `dismiss` would
    /// be a no-op that may never call its completion — so check before relying
    /// on it.
    private func showOutcome(after progress: UIAlertController, _ outcome: @escaping () -> Void) {
        if progress.presentingViewController != nil {
            progress.dismiss(animated: true, completion: outcome)
        } else {
            outcome()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
