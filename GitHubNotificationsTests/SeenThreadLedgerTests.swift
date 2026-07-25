import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct SeenThreadLedgerTests {
    private let firstUpdate = Date(timeIntervalSince1970: 1_700_000_000)
    private let secondUpdate = Date(timeIntervalSince1970: 1_700_000_600)

    @Test
    func announcesNothingOnTheFirstFetchAfterSigningIn() {
        let ledger = makeLedger()
        let inbox = [Fixtures.thread(id: "a"), Fixtures.thread(id: "b")]

        #expect(ledger.selectThreadsToAnnounce(from: inbox).isEmpty)
    }

    @Test
    func announcesThreadsThatArriveAfterSeeding() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a"), Fixtures.thread(id: "b")])

        #expect(announced.map(\.id) == ["b"])
    }

    @Test
    func announcesAThreadAgainWhenItIsUpdated() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: secondUpdate)])

        #expect(announced.map(\.id) == ["a"])
    }

    @Test
    func doesNotAnnounceAnUnchangedThread() {
        let ledger = makeLedger()
        let inbox = [Fixtures.thread(id: "a", updatedAt: firstUpdate)]
        _ = ledger.selectThreadsToAnnounce(from: inbox)

        #expect(ledger.selectThreadsToAnnounce(from: inbox).isEmpty)
    }

    @Test
    func doesNotAnnounceAThreadThatIsAlreadyRead() {
        let ledger = makeLedger()
        _ = ledger.selectThreadsToAnnounce(from: [])

        let announced = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", isUnread: false)])

        #expect(announced.isEmpty)
    }

    @Test
    func survivesARestart() {
        let fileURL = temporaryFileURL()
        let firstRun = makeLedger(fileURL: fileURL)
        _ = firstRun.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        let secondRun = makeLedger(fileURL: fileURL)
        let announced = secondRun.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a", updatedAt: firstUpdate)])

        #expect(announced.isEmpty)
    }

    @Test
    func startsFreshAfterBeingCleared() {
        let fileURL = temporaryFileURL()
        let ledger = makeLedger(fileURL: fileURL)
        _ = ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")])

        ledger.clear()

        #expect(ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "a")]).isEmpty)
        #expect(ledger.selectThreadsToAnnounce(from: [Fixtures.thread(id: "b")]).map(\.id) == ["b"])
    }

    private func makeLedger(fileURL: URL? = nil) -> SeenThreadLedger {
        SeenThreadLedger(fileURL: fileURL ?? temporaryFileURL(), log: AppLog(subsystem: "tests"))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString).json")
    }
}
