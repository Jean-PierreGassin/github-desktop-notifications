import Foundation

/// Whether the app looks for its own updates, and when it last did.
///
/// Checking is on out of the box and asks no permission: a menu bar app that
/// silently rots is worse than one that quietly looks. Installing is the part
/// that always asks.
@MainActor
@Observable
final class UpdatePreferences {
    static let defaultChecksAutomatically = true

    private static let checksAutomaticallyKey = "checksForUpdatesAutomatically"
    private static let lastCheckedAtKey = "lastUpdateCheckAt"

    private let defaults: UserDefaults

    var checksAutomatically: Bool {
        didSet { defaults.set(checksAutomatically, forKey: Self.checksAutomaticallyKey) }
    }

    var lastCheckedAt: Date? {
        didSet { defaults.set(lastCheckedAt, forKey: Self.lastCheckedAtKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        checksAutomatically = defaults.object(forKey: Self.checksAutomaticallyKey) as? Bool
            ?? Self.defaultChecksAutomatically
        lastCheckedAt = defaults.object(forKey: Self.lastCheckedAtKey) as? Date
    }

    func resetToDefaults() {
        checksAutomatically = Self.defaultChecksAutomatically
    }
}
