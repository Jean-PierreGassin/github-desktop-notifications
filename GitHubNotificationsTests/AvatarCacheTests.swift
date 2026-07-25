import AppKit
import Foundation
import Testing

@testable import GitHubNotifications

/// Serialised because the stub's handler and request log are class-level state,
/// exactly as the client suites are.
@MainActor
@Suite(.serialized)
struct AvatarCacheTests {
    @Test
    func answersWithoutWaitingAndFillsInAfterwards() async throws {
        let session = StubAvatarProtocol.makeSession()
        StubAvatarProtocol.respond = { _ in (statusCode: 200, body: Self.pngBody) }
        let cache = makeCache(directory: Fixtures.temporaryDirectory(), session: session)

        #expect(cache.image(for: Self.owner) == nil)

        try await waitForFetch()

        #expect(cache.image(for: Self.owner) != nil)
    }

    @Test
    func aCachedAvatarSurvivesARelaunchWithoutFetchingAgain() async throws {
        let directory = Fixtures.temporaryDirectory()
        let session = StubAvatarProtocol.makeSession()
        StubAvatarProtocol.respond = { _ in (statusCode: 200, body: Self.pngBody) }
        let cache = makeCache(directory: directory, session: session)
        _ = cache.image(for: Self.owner)

        try await waitForFetch()

        StubAvatarProtocol.receivedRequests = []
        let afterRelaunch = makeCache(directory: directory, session: session)

        #expect(afterRelaunch.image(for: Self.owner) != nil)
        #expect(StubAvatarProtocol.receivedRequests.isEmpty)
    }

    @Test
    func asksForASmallImageRatherThanTheFullSizeOne() async throws {
        let session = StubAvatarProtocol.makeSession()
        StubAvatarProtocol.respond = { _ in (statusCode: 200, body: Self.pngBody) }

        let cache = makeCache(directory: Fixtures.temporaryDirectory(), session: session)
        _ = cache.image(for: Self.owner)

        try await waitForFetch()

        #expect(StubAvatarProtocol.receivedRequests.first?.url?.query == "s=64")
    }

    @Test
    func aFailedFetchLeavesTheRowWithoutAnAvatarRatherThanBreaking() async throws {
        let session = StubAvatarProtocol.makeSession()
        StubAvatarProtocol.respond = { _ in (statusCode: 404, body: Data()) }
        let cache = makeCache(directory: Fixtures.temporaryDirectory(), session: session)

        _ = cache.image(for: Self.owner)

        try await waitForFetch()

        #expect(cache.image(for: Self.owner) == nil)
    }

    private static let owner = RepositoryOwner(
        login: "acme",
        avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"),
    )

    /// The smallest thing `NSImage` will decode: a one pixel PNG.
    private static let pngBody = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
    )!

    private func makeCache(directory: URL, session: URLSession) -> AvatarCache {
        AvatarCache(directory: directory, session: session, log: AppLog(subsystem: "tests"))
    }

    private func waitForFetch() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }
}
