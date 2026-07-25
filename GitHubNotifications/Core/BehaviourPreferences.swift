import Foundation

/// Preferences about how the app behaves when you use it, as opposed to what it
/// notifies you about.
@MainActor
@Observable
final class BehaviourPreferences {
    private static let clickBehaviourKey = "clickBehaviour"
    private static let hasChosenClickBehaviourKey = "hasChosenClickBehaviour"

    /// The boolean this preference replaced. Read once to carry the existing
    /// choice across, then deleted.
    private static let retiredMarksAsReadOnOpenKey = "marksAsReadOnOpen"
    private static let retiredHasChosenKey = "hasChosenMarkAsReadBehaviour"

    private let defaults: UserDefaults

    var clickBehaviour: ClickBehaviour {
        didSet { defaults.set(clickBehaviour.rawValue, forKey: Self.clickBehaviourKey) }
    }

    /// The choice is offered once, right after signing in.
    var hasChosenClickBehaviour: Bool {
        didSet { defaults.set(hasChosenClickBehaviour, forKey: Self.hasChosenClickBehaviourKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        clickBehaviour = Self.storedBehaviour(in: defaults) ?? Self.migratedBehaviour(in: defaults) ?? .default
        hasChosenClickBehaviour = defaults.bool(forKey: Self.hasChosenClickBehaviourKey)
            || defaults.bool(forKey: Self.retiredHasChosenKey)

        Self.retireOldKeys(in: defaults)
    }

    func resetToDefaults() {
        clickBehaviour = .default
    }

    private static func storedBehaviour(in defaults: UserDefaults) -> ClickBehaviour? {
        defaults.string(forKey: clickBehaviourKey).flatMap(ClickBehaviour.init(rawValue:))
    }

    /// Marking as read on open meant clearing the thread from GitHub as well as
    /// from here, which is now Read & Dismissed. Leaving it off meant only ever
    /// marking read by hand, which is closest to Read.
    private static func migratedBehaviour(in defaults: UserDefaults) -> ClickBehaviour? {
        guard let marksAsReadOnOpen = defaults.object(forKey: retiredMarksAsReadOnOpenKey) as? Bool else {
            return nil
        }

        return marksAsReadOnOpen ? .readAndDismissed : .read
    }

    private static func retireOldKeys(in defaults: UserDefaults) {
        defaults.removeObject(forKey: retiredMarksAsReadOnOpenKey)
        defaults.removeObject(forKey: retiredHasChosenKey)
    }
}
