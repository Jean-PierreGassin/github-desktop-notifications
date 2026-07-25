import Foundation

/// What the app puts into a macOS notification. These only affect the alert
/// itself, never the menu bar panel.
struct NotificationContentSettings: Sendable, Equatable, Codable {
    var showsRepository = true
    var showsFullRepositoryPath = true
    var showsNotificationType = true
    var showsThreadTitle = true
    var groupsByRepository = true
    var playsSound = true
    var sound = NotificationSound.systemDefault
}

struct NotificationContentText: Sendable, Equatable {
    let title: String
    let subtitle: String
    let body: String
}

/// Builds the text of a notification from the user's choices, never leaving it
/// blank however much has been switched off.
enum NotificationContentFormatter {
    private static let fallbackTitle = "GitHub"

    static func make(
        for thread: NotificationThread,
        settings: NotificationContentSettings,
    ) -> NotificationContentText {
        let repositoryName = repositoryName(for: thread.repository, settings: settings)
        let reasonName = thread.reason.displayName
        let threadTitle = thread.subject.title

        guard settings.showsThreadTitle else {
            return NotificationContentText(
                title: repositoryName ?? fallbackTitle,
                subtitle: "",
                body: settings.showsNotificationType ? reasonName : threadTitle,
            )
        }

        return NotificationContentText(
            title: repositoryName ?? fallbackTitle,
            subtitle: settings.showsNotificationType ? reasonName : "",
            body: threadTitle,
        )
    }

    private static func repositoryName(
        for repository: NotificationRepository,
        settings: NotificationContentSettings,
    ) -> String? {
        guard settings.showsRepository else {
            return nil
        }

        return settings.showsFullRepositoryPath ? repository.fullName : repository.name
    }
}

/// Persists the notification content choices.
@MainActor
@Observable
final class NotificationContentPreferences {
    private static let storageKey = "notificationContentSettings"

    private let defaults: UserDefaults

    var settings: NotificationContentSettings {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard let stored = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(NotificationContentSettings.self, from: stored)
        else {
            settings = NotificationContentSettings()
            return
        }

        settings = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(encoded, forKey: Self.storageKey)
    }
}
