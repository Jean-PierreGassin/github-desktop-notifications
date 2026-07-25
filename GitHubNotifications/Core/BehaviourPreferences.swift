import Foundation

/// Preferences about how the app behaves when you use it, as opposed to what it
/// notifies you about.
@MainActor
@Observable
final class BehaviourPreferences {
    private static let marksAsReadOnOpenKey = "marksAsReadOnOpen"
    private static let hasChosenMarkAsReadBehaviourKey = "hasChosenMarkAsReadBehaviour"

    private let defaults: UserDefaults

    /// Opening a notification usually means you have dealt with it, but some
    /// people keep their inbox as a to-do list.
    var marksAsReadOnOpen: Bool {
        didSet { defaults.set(marksAsReadOnOpen, forKey: Self.marksAsReadOnOpenKey) }
    }

    /// The choice is offered once, the first time a notification is opened.
    var hasChosenMarkAsReadBehaviour: Bool {
        didSet { defaults.set(hasChosenMarkAsReadBehaviour, forKey: Self.hasChosenMarkAsReadBehaviourKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        marksAsReadOnOpen = defaults.object(forKey: Self.marksAsReadOnOpenKey) as? Bool ?? true
        hasChosenMarkAsReadBehaviour = defaults.bool(forKey: Self.hasChosenMarkAsReadBehaviourKey)
    }
}
