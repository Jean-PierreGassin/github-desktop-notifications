import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct HeldAlertQueueTests {
    @Test
    func holdsAndReleasesInOneGo() {
        let queue = makeQueue()

        queue.hold([announcement(id: "a"), announcement(id: "b")])

        #expect(queue.heldAnnouncements.count == 2)
        #expect(queue.drain().map(\.id) == ["a", "b"])
        #expect(queue.isEmpty)
    }

    @Test
    func doesNotHoldTheSameThreadTwice() {
        let queue = makeQueue()

        queue.hold([announcement(id: "a")])
        queue.hold([announcement(id: "a"), announcement(id: "b")])

        #expect(queue.heldAnnouncements.map(\.id) == ["a", "b"])
    }

    @Test
    func survivesARestartWithWhatChangedIntact() {
        let fileURL = temporaryFileURL()
        makeQueue(fileURL: fileURL).hold([announcement(id: "a", update: .comment)])

        let released = makeQueue(fileURL: fileURL).heldAnnouncements

        #expect(released.map(\.id) == ["a"])
        #expect(released.map(\.update) == [.comment])
    }

    /// Alerts held by a version that stored bare threads still have to be
    /// delivered, rather than being dropped on the first launch after updating.
    @Test
    func readsAlertsHeldBeforeWhatChangedWasStored() throws {
        let fileURL = temporaryFileURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([Fixtures.thread(id: "a")]).write(to: fileURL)

        let held = makeQueue(fileURL: fileURL).heldAnnouncements

        #expect(held.map(\.id) == ["a"])
        #expect(held.map(\.update) == [.reasonForNotifying])
    }

    @Test
    func forgetsHeldAlertsOnSignOut() {
        let fileURL = temporaryFileURL()
        let queue = makeQueue(fileURL: fileURL)
        queue.hold([announcement(id: "a")])

        queue.clear()

        #expect(makeQueue(fileURL: fileURL).isEmpty)
    }

    private func announcement(id: String, update: ThreadUpdate = .reasonForNotifying) -> ThreadAnnouncement {
        Fixtures.announcement(thread: Fixtures.thread(id: id), update: update)
    }

    private func makeQueue(fileURL: URL? = nil) -> HeldAlertQueue {
        HeldAlertQueue(fileURL: fileURL ?? temporaryFileURL(), log: AppLog(subsystem: "tests"))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "held-\(UUID().uuidString).json")
    }
}
