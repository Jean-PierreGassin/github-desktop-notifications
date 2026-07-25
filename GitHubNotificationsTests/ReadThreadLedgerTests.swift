import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct ReadThreadLedgerTests {
    @Test
    func aReadRowSurvivesARestart() {
        let fileURL = Fixtures.temporaryDirectory().appending(path: "read-threads.json")
        makeLedger(at: fileURL).record(Fixtures.thread(id: "1"))

        let afterRestart = makeLedger(at: fileURL)

        #expect(afterRestart.contains("1"))
        #expect(afterRestart.threads.first?.isUnread == false)
    }

    @Test
    func keepingOnlyWhatTheInboxHoldsDropsTheRest() {
        let ledger = makeLedger()
        ledger.record(Fixtures.thread(id: "1"))
        ledger.record(Fixtures.thread(id: "2"))

        ledger.keepOnly(["2"])

        #expect(ledger.identifiers == ["2"])
    }

    @Test
    func clearingLeavesNothingBehindForTheNextSignIn() {
        let fileURL = Fixtures.temporaryDirectory().appending(path: "read-threads.json")
        let ledger = makeLedger(at: fileURL)
        ledger.record(Fixtures.thread(id: "1"))

        ledger.clear()

        #expect(makeLedger(at: fileURL).identifiers.isEmpty)
    }

    private func makeLedger(at fileURL: URL? = nil) -> ReadThreadLedger {
        ReadThreadLedger(
            fileURL: fileURL ?? Fixtures.temporaryDirectory().appending(path: "read-threads.json"),
            log: AppLog(subsystem: "tests"),
        )
    }
}
