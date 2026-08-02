import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct OwnerPreferencesTests {
    @Test
    func lettingEveryoneThroughIsTheStartingPoint() {
        let preferences = makePreferences()
        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "jp")])

        #expect(preferences.allowsAlert(from: "acme"))
        #expect(preferences.allowsAlert(from: "jp"))
        #expect(preferences.mutedOwnerKeys.isEmpty)
    }

    /// The point of the setting: work is off on this machine and the personal
    /// account is untouched.
    @Test
    func mutingAnOwnerSilencesThatOwnerAlone() {
        let preferences = makePreferences()
        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "jp")])

        preferences.setMuted(true, for: "acme")

        #expect(!preferences.allowsAlert(from: "acme"))
        #expect(preferences.allowsAlert(from: "jp"))
        #expect(preferences.mutedOwnerKeys == ["acme"])
    }

    /// GitHub answers with whatever case an owner registered and treats every
    /// spelling of it as the same account, so a stored mute has to as well.
    @Test(arguments: ["ACME", "Acme", "acme"])
    func aMuteHoldsHoweverTheLoginIsSpelt(login: String) {
        let preferences = makePreferences()

        preferences.setMuted(true, for: "AcMe")

        #expect(!preferences.allowsAlert(from: login))
        #expect(preferences.isMuted(login))
    }

    @Test
    func unmutingLetsAnOwnerBackIn() {
        let preferences = makePreferences()
        preferences.setMuted(true, for: "acme")

        preferences.setMuted(false, for: "ACME")

        #expect(preferences.allowsAlert(from: "acme"))
        #expect(preferences.mutedOwners.isEmpty)
    }

    @Test
    func aMuteSurvivesTheNextLaunch() {
        let defaults = makeDefaults()
        let preferences = OwnerPreferences(defaults: defaults)
        preferences.rememberOwners(of: [thread(ownedBy: "acme")])
        preferences.setMuted(true, for: "acme")

        let secondLaunch = OwnerPreferences(defaults: defaults)

        #expect(!secondLaunch.allowsAlert(from: "acme"))
        #expect(secondLaunch.listedOwners == ["acme"])
    }

    @Test
    func learningTheSameOwnerTwiceListsThemOnce() {
        let preferences = makePreferences()

        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "ACME")])
        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "jp")])

        #expect(preferences.listedOwners == ["acme", "jp"])
    }

    @Test
    func listsOwnersInTheOrderANameListIsRead() {
        let preferences = makePreferences()

        preferences.rememberOwners(of: [thread(ownedBy: "zeta"), thread(ownedBy: "Acme"), thread(ownedBy: "jp")])

        #expect(preferences.listedOwners == ["Acme", "jp", "zeta"])
    }

    /// A muted owner that fell off the list would go on being silenced with
    /// nothing on the page to say so, and no way to switch it back on.
    @Test
    func aMutedOwnerStaysOnTheListAfterSigningOut() {
        let preferences = makePreferences()
        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "jp")])
        preferences.setMuted(true, for: "acme")

        preferences.forgetKnownOwners()

        #expect(preferences.listedOwners == ["acme"])
        #expect(!preferences.allowsAlert(from: "acme"))
    }

    /// The list is what has arrived rather than a preference, so resetting has
    /// nothing to say about it.
    @Test
    func resettingUnmutesEveryoneWithoutEmptyingTheList() {
        let preferences = makePreferences()
        preferences.rememberOwners(of: [thread(ownedBy: "acme"), thread(ownedBy: "jp")])
        preferences.setMuted(true, for: "acme")

        preferences.resetToDefaults()

        #expect(preferences.allowsAlert(from: "acme"))
        #expect(preferences.listedOwners == ["acme", "jp"])
    }

    /// The panel is re-filtered from this, and polling is conditional: an
    /// unchanged inbox answers 304, so nothing else would tell it to.
    @Test
    func announcesEveryChangeToWhoIsMuted() {
        let preferences = makePreferences()
        var changeCount = 0
        preferences.onMutedOwnersChanged = { changeCount += 1 }

        preferences.setMuted(true, for: "acme")
        preferences.setMuted(true, for: "acme")
        preferences.setMuted(false, for: "acme")
        preferences.resetToDefaults()

        #expect(changeCount == 3)
    }

    private func thread(ownedBy owner: String) -> NotificationThread {
        Fixtures.thread(repository: Fixtures.repository(fullName: "\(owner)/api"))
    }

    private func makePreferences() -> OwnerPreferences {
        OwnerPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "owner-preferences-tests-\(UUID().uuidString)")!
    }
}
