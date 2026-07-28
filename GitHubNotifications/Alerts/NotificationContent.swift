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
///
/// The middle line is what the announcement is about rather than the thread's
/// standing reason, so the comment that follows a review request does not arrive
/// wearing the review request's words.
enum NotificationContentFormatter {
    private static let fallbackTitle = "GitHub"

    static func make(
        for announcement: ThreadAnnouncement,
        settings: NotificationContentSettings,
    ) -> NotificationContentText {
        let thread = announcement.thread
        let repositoryName = repositoryName(for: thread.repository, settings: settings)
        let updateSummary = announcement.update.summary(for: thread.reason)
        let threadTitle = thread.subject.title

        guard settings.showsThreadTitle else {
            return NotificationContentText(
                title: repositoryName ?? fallbackTitle,
                subtitle: "",
                body: settings.showsNotificationType ? updateSummary : threadTitle,
            )
        }

        return NotificationContentText(
            title: repositoryName ?? fallbackTitle,
            subtitle: settings.showsNotificationType ? updateSummary : "",
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

    /// Settings reset one section at a time, so what a banner says and how it
    /// behaves are restored separately. Both read their defaults from a fresh
    /// ``NotificationContentSettings`` rather than repeating them.
    func resetContent() {
        let defaults = NotificationContentSettings()

        settings.showsRepository = defaults.showsRepository
        settings.showsFullRepositoryPath = defaults.showsFullRepositoryPath
        settings.showsThreadTitle = defaults.showsThreadTitle
        settings.showsNotificationType = defaults.showsNotificationType
    }

    func resetBehaviour() {
        let defaults = NotificationContentSettings()

        settings.groupsByRepository = defaults.groupsByRepository
        settings.playsSound = defaults.playsSound
        settings.sound = defaults.sound
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(encoded, forKey: Self.storageKey)
    }
}
