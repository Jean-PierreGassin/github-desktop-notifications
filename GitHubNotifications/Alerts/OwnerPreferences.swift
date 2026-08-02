import Foundation

/// Whose notifications this machine wants.
///
/// One GitHub account is usually read from more than one Mac, and the same inbox
/// is rarely wanted on both: work pull requests do not need to reach a personal
/// machine at the weekend, and a hobby repository does not need to interrupt a
/// working day. Nothing on a notification says which of those it is except who
/// owns the repository it came from, so that is what this switches on and off.
///
/// It is a machine's setting rather than an account's, which is why it lives in
/// defaults and is never synchronised. Muting work here is not unsubscribing:
/// GitHub still has the notification, the web inbox still shows it, and the
/// other Mac still alerts on it.
///
/// Owners are learnt from the inbox rather than asked of GitHub. An account's
/// list of organisations leaves out its own repositories, its forks, and the
/// one-off repository someone was invited to, and all three send notifications.
/// So an owner appears here the first time something of theirs arrives, already
/// switched on: a filter nobody has touched must never be the reason a
/// notification went missing.
@MainActor
@Observable
final class OwnerPreferences {
    private static let mutedOwnersKey = "mutedOwners"
    private static let knownOwnersKey = "knownOwners"

    private let defaults: UserDefaults

    /// The owners switched off on this machine, and the owners it has seen at
    /// all. Both are kept because they answer different questions: one is the
    /// setting, the other is the list the setting is offered on.
    ///
    /// Logins are held as GitHub spelt them so the list reads the way the site
    /// does, and compared without case, because GitHub treats two spellings of a
    /// login as the same account.
    private(set) var mutedOwners: [String]
    private(set) var knownOwners: [String]

    /// Called whenever the muted set changes, so the panel can be re-filtered
    /// there and then. Polling is conditional and an unchanged inbox answers 304,
    /// so waiting for the next fetch could leave a muted owner's rows on screen
    /// until something unrelated happened.
    var onMutedOwnersChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        mutedOwners = defaults.stringArray(forKey: Self.mutedOwnersKey) ?? []
        knownOwners = defaults.stringArray(forKey: Self.knownOwnersKey) ?? []
    }

    /// Every owner worth offering a switch for, in the order a list of names
    /// should be read in.
    ///
    /// Muted owners are in it whether or not they are still sending anything. One
    /// that dropped off the list would go on being silenced with nothing on the
    /// page to say so and no way to switch it back on, which is the one failure
    /// this setting must not have.
    var listedOwners: [String] {
        let unseenButMuted = mutedOwners.filter { !isKnown($0) }

        return (knownOwners + unseenButMuted)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// The muted logins folded to lower case, ready to filter rows against.
    var mutedOwnerKeys: Set<String> {
        Set(mutedOwners.map { $0.lowercased() })
    }

    func allowsAlert(from login: String) -> Bool {
        !isMuted(login)
    }

    func isMuted(_ login: String) -> Bool {
        mutedOwners.contains { $0.caseInsensitiveCompare(login) == .orderedSame }
    }

    func setMuted(_ isMuted: Bool, for login: String) {
        guard isMuted != self.isMuted(login) else {
            return
        }

        if isMuted {
            mutedOwners.append(login)
        } else {
            mutedOwners.removeAll { $0.caseInsensitiveCompare(login) == .orderedSame }
        }

        save()
    }

    /// Learns the owners in a fetch, so Settings offers a switch for each of them.
    ///
    /// Every fetch is passed through, not only the threads that earned an alert:
    /// the whole point of the list is to switch off an owner whose notifications
    /// are arriving, and one that never reached the panel is exactly the one
    /// someone came here to find.
    func rememberOwners(of threads: [NotificationThread]) {
        var arrivals: [String] = []

        for login in threads.map(\.repository.owner.login)
            where !isKnown(login) && !arrivals.contains(where: { $0.caseInsensitiveCompare(login) == .orderedSame }) {
            arrivals.append(login)
        }

        guard !arrivals.isEmpty else {
            return
        }

        knownOwners += arrivals
        defaults.set(knownOwners, forKey: Self.knownOwnersKey)
    }

    /// Signing out must not leave the next account reading the last one's list of
    /// organisations. What was muted survives, because signing back in should not
    /// quietly undo it, and ``listedOwners`` keeps it switchable in the meantime.
    func forgetKnownOwners() {
        knownOwners = []
        defaults.set(knownOwners, forKey: Self.knownOwnersKey)
    }

    /// Resetting unmutes everyone rather than emptying the list. The list is what
    /// has arrived, not a preference, and clearing it would take the switches away
    /// until each owner sent something again.
    func resetToDefaults() {
        mutedOwners = []
        save()
    }

    private func isKnown(_ login: String) -> Bool {
        knownOwners.contains { $0.caseInsensitiveCompare(login) == .orderedSame }
    }

    private func save() {
        defaults.set(mutedOwners, forKey: Self.mutedOwnersKey)

        onMutedOwnersChanged?()
    }
}
