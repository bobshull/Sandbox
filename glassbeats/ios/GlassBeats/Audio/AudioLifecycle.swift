import Foundation

/// Lifecycle inputs that affect the audio engine, reduced to pure data so the
/// response policy is unit-testable without AVFoundation.
enum AudioLifecycleEvent: Equatable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case mediaServicesReset
    case configurationChange
    case appBackgrounded
    case appForegrounded
}

enum AudioLifecycleAction: Equatable {
    case stopTransport
    case reactivateEngine
    case rebuildGraph
    case pauseEngineIfIdle
}

/// Pure mapping from lifecycle events to engine actions. AudioEngine's
/// notification handlers stay thin and just execute what this table decides.
///
/// Policy notes:
/// - Transport never auto-resumes after an interruption; the user presses play.
///   The engine is only made ready again (`.reactivateEngine`) so that play is
///   instant.
/// - Engine restart is otherwise lazy: start()/preview() bring the engine back
///   on demand, so "do nothing" is a valid recovery for the stopped state.
/// - Backgrounding while playing is legitimate background audio; backgrounding
///   while idle pauses the engine so the app stops rendering silence and can
///   suspend.
enum AudioLifecyclePolicy {
    static func actions(for event: AudioLifecycleEvent, isPlaying: Bool) -> [AudioLifecycleAction] {
        switch event {
        case .interruptionBegan:
            return isPlaying ? [.stopTransport] : []
        case .interruptionEnded(let shouldResume):
            return shouldResume ? [.reactivateEngine] : []
        case .mediaServicesReset:
            return isPlaying ? [.stopTransport, .rebuildGraph] : [.rebuildGraph]
        case .configurationChange:
            return isPlaying ? [.stopTransport, .reactivateEngine] : []
        case .appBackgrounded:
            return isPlaying ? [] : [.pauseEngineIfIdle]
        case .appForegrounded:
            return []
        }
    }
}
