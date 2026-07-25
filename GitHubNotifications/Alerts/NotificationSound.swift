import AppKit
import UserNotifications

/// The sounds a notification can play. These are the sounds macOS ships in
/// `/System/Library/Sounds`, so nothing has to be bundled with the app.
enum NotificationSound: String, Sendable, Codable, CaseIterable {
    case systemDefault
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"

    var displayName: String {
        self == .systemDefault ? "Default" : rawValue
    }

    var notificationSound: UNNotificationSound {
        guard self != .systemDefault else {
            return .default
        }

        return UNNotificationSound(named: UNNotificationSoundName("\(rawValue).aiff"))
    }

    /// Plays the sound directly so the user can compare options without waiting
    /// for a real notification.
    @MainActor
    func play() {
        guard self != .systemDefault else {
            NSSound(named: "Funk")?.play()
            return
        }

        NSSound(named: rawValue)?.play()
    }
}
