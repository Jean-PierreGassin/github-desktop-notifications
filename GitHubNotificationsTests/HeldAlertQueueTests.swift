import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct HeldAlertQueueTests {
    @Test
    func holdsAndReleasesInOneGo() {
        let queue = makeQueue()

        queue.hold([Fixtures.thread(id: "a"), Fixtures.thread(id: "b")])

        #expect(queue.heldThreads.count == 2)
        #expect(queue.drain().map(\.id) == ["a", "b"])
        #expect(queue.isEmpty)
    }

    @Test
    func doesNotHoldTheSameThreadTwice() {
        let queue = makeQueue()

        queue.hold([Fixtures.thread(id: "a")])
        queue.hold([Fixtures.thread(id: "a"), Fixtures.thread(id: "b")])

        #expect(queue.heldThreads.map(\.id) == ["a", "b"])
    }

    @Test
    func survivesARestart() {
        let fileURL = temporaryFileURL()
        makeQueue(fileURL: fileURL).hold([Fixtures.thread(id: "a")])

        #expect(makeQueue(fileURL: fileURL).heldThreads.map(\.id) == ["a"])
    }

    @Test
    func forgetsHeldAlertsOnSignOut() {
        let fileURL = temporaryFileURL()
        let queue = makeQueue(fileURL: fileURL)
        queue.hold([Fixtures.thread(id: "a")])

        queue.clear()

        #expect(makeQueue(fileURL: fileURL).isEmpty)
    }

    private func makeQueue(fileURL: URL? = nil) -> HeldAlertQueue {
        HeldAlertQueue(fileURL: fileURL ?? temporaryFileURL(), log: AppLog(subsystem: "tests"))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "held-\(UUID().uuidString).json")
    }
}
