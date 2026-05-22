import Foundation

enum AppSettings {
    private static let local = UserDefaults.standard

    private static let hapticsKey     = "pulse.hapticsEnabled"
    private static let tempoKey       = "pulse.defaultTempo"
    private static let colorThemeKey  = "pulse.colorThemeId"

    static var hapticsEnabled: Bool {
        get { local.object(forKey: hapticsKey) == nil ? true : local.bool(forKey: hapticsKey) }
        set { local.set(newValue, forKey: hapticsKey) }
    }

    static var defaultTempo: Double {
        get { local.object(forKey: tempoKey) == nil ? 96 : local.double(forKey: tempoKey) }
        set { local.set(newValue, forKey: tempoKey) }
    }

    static var colorThemeId: String {
        get { local.string(forKey: colorThemeKey) ?? "neon" }
        set {
            local.set(newValue, forKey: colorThemeKey)
            NotificationCenter.default.post(name: .colorThemeDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let colorThemeDidChange = Notification.Name("pulse.colorThemeDidChange")
}
