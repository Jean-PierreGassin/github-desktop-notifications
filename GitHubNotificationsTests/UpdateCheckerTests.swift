import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct UpdateCheckerTests {
    @Test
    func offersAReleaseNewerThanTheOneRunning() async {
        let checker = makeChecker(latest: release(version: "1.3.0"), currentVersion: "1.2.0")

        await checker.check(usingToken: nil, isManual: true)

        #expect(checker.state == .available(release(version: "1.3.0")))
    }

    @Test(arguments: ["1.2.0", "1.1.9", "0.9.0"])
    func neverOffersToGoBackwardsOrSideways(publishedVersion: String) async {
        let checker = makeChecker(latest: release(version: publishedVersion), currentVersion: "1.2.0")

        await checker.check(usingToken: nil, isManual: true)

        #expect(checker.state == .upToDate(checkedAt: Self.now))
    }

    @Test
    func comparesVersionsByComponentRatherThanAsText() async {
        let checker = makeChecker(latest: release(version: "1.10.0"), currentVersion: "1.9.0")

        await checker.check(usingToken: nil, isManual: true)

        #expect(checker.state == .available(release(version: "1.10.0")))
    }

    @Test
    func checksOnceADayAtMost() async {
        let source = FakeReleaseSource(latest: release(version: "1.3.0"))
        let preferences = makePreferences()
        preferences.lastCheckedAt = Self.now.addingTimeInterval(-3600)
        let checker = makeChecker(source: source, preferences: preferences)

        await checker.checkIfDue(usingToken: nil)

        #expect(source.fetchCount == 0)

        preferences.lastCheckedAt = Self.now.addingTimeInterval(-25 * 60 * 60)
        await checker.checkIfDue(usingToken: nil)

        #expect(source.fetchCount == 1)
    }

    @Test
    func doesNotCheckAutomaticallyWhenTurnedOff() async {
        let source = FakeReleaseSource(latest: release(version: "1.3.0"))
        let preferences = makePreferences()
        preferences.checksAutomatically = false

        await makeChecker(source: source, preferences: preferences).checkIfDue(usingToken: nil)

        #expect(source.fetchCount == 0)
    }

    @Test
    func keepsAFailedAutomaticCheckOutOfTheUsersWay() async {
        let checker = makeChecker(source: FakeReleaseSource(failure: .offline))

        await checker.checkIfDue(usingToken: nil)

        #expect(checker.state == .idle)
    }

    @Test
    func showsAFailureTheUserAskedFor() async {
        let checker = makeChecker(source: FakeReleaseSource(failure: .offline))

        await checker.check(usingToken: nil, isManual: true)

        #expect(checker.state == .failed(GitHubError.offline.userFacingMessage))
    }

    @Test
    func treatsAReleaseWithoutAUsableAssetAsNothingToDo() async {
        let checker = makeChecker(latest: nil, currentVersion: "1.2.0")

        await checker.check(usingToken: nil, isManual: true)

        #expect(checker.state == .upToDate(checkedAt: Self.now))
    }

    @Test
    func recordsWhenItLastLookedSoTheDailyFloorSurvivesARestart() async {
        let preferences = makePreferences()

        await makeChecker(preferences: preferences).check(usingToken: nil, isManual: true)

        #expect(preferences.lastCheckedAt == Self.now)
    }

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func release(version: String) -> Release {
        Release(
            version: version,
            pageURL: URL(string: "https://example.invalid/releases/\(version)")!,
            downloadURL: URL(string: "https://example.invalid/GitHubNotifications-\(version).zip")!,
            publishedAt: Self.now,
        )
    }

    private func makeChecker(
        source: FakeReleaseSource? = nil,
        latest: Release? = nil,
        preferences: UpdatePreferences? = nil,
        currentVersion: String = "1.2.0",
    ) -> UpdateChecker {
        UpdateChecker(
            source: source ?? FakeReleaseSource(latest: latest),
            installer: FakeUpdateInstaller(),
            preferences: preferences ?? makePreferences(),
            log: AppLog(subsystem: "tests"),
            currentVersion: currentVersion,
            now: { Self.now },
        )
    }

    private func makePreferences() -> UpdatePreferences {
        UpdatePreferences(defaults: UserDefaults(suiteName: "update-preferences-tests-\(UUID().uuidString)")!)
    }
}

private final class FakeReleaseSource: ReleaseSource, @unchecked Sendable {
    private let latest: Release?
    private let failure: GitHubError?

    private(set) var fetchCount = 0

    init(latest: Release? = nil, failure: GitHubError? = nil) {
        self.latest = latest
        self.failure = failure
    }

    func fetchLatestRelease(usingToken token: String?) async throws -> Release? {
        fetchCount += 1

        if let failure {
            throw failure
        }

        return latest
    }
}

private struct FakeUpdateInstaller: UpdateInstalling {
    func downloadAndVerify(_ release: Release) async throws -> URL {
        URL(filePath: "/tmp/GitHub Notifications.app")
    }

    func install(from bundleURL: URL, relaunching: Bool) throws {}
}
