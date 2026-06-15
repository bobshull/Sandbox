import Foundation

enum ExportFormat: String { case wav, m4a }

enum AppSettings {
    private static let local = UserDefaults.standard

    private static let hapticsKey    = "glassbeats.hapticsEnabled"
    private static let tempoKey      = "glassbeats.defaultTempo"
    private static let colorThemeKey = "glassbeats.colorThemeId"
    private static let launchTourIntroKey = "glassbeats.hasHandledLaunchTourIntro"

    static var hapticsEnabled: Bool {
        get { local.object(forKey: hapticsKey) == nil ? true : local.bool(forKey: hapticsKey) }
        set { local.set(newValue, forKey: hapticsKey) }
    }

    static var defaultTempo: Double {
        get { local.object(forKey: tempoKey) == nil ? 96 : local.double(forKey: tempoKey) }
        set { local.set(newValue, forKey: tempoKey) }
    }

    static var colorThemeId: String {
        get { local.string(forKey: colorThemeKey) ?? "mangoTango" }
        set {
            local.set(newValue, forKey: colorThemeKey)
            NotificationCenter.default.post(name: .colorThemeDidChange, object: nil)
        }
    }

    static var hasHandledLaunchTourIntro: Bool {
        get { local.bool(forKey: launchTourIntroKey) }
        set { local.set(newValue, forKey: launchTourIntroKey) }
    }

}

extension Notification.Name {
    static let colorThemeDidChange = Notification.Name("glassbeats.colorThemeDidChange")
    static let replayLaunchTourRequested = Notification.Name("glassbeats.replayLaunchTourRequested")
}
