import Foundation

struct NotificationsResponse: Sendable {
    let threads: [NotificationThread]
    let isUnchanged: Bool
    let lastModified: String?
    let pollInterval: TimeInterval?
}

extension GitHubClient {
    private static let threadsPerPage = 50
    private static let pageLimit = 5
    private static let timelineEventsPerPage = 100

    /// Asks conditionally first, then fetches the whole inbox when something has
    /// changed.
    ///
    /// A conditional request is worth making because a `304` is free, but the
    /// `200` that follows a change is **not** the full inbox: GitHub answers with
    /// only the threads updated since the given timestamp. Treating that delta as
    /// the whole inbox silently drops every notification that did not just
    /// change, so the real list is always re-read unconditionally.
    func fetchNotifications(usingToken token: String, since lastModified: String?) async throws -> NotificationsResponse {
        if let lastModified {
            let probe = makeRequest(path: "/notifications", token: token, lastModified: lastModified)
            let (_, probeResponse, probeHeaders) = try await send(probe)
            try throwIfUnsuccessful(response: probeResponse, headers: probeHeaders)

            guard probeResponse.statusCode != 304 else {
                return NotificationsResponse(
                    threads: [],
                    isUnchanged: true,
                    lastModified: lastModified,
                    pollInterval: probeHeaders.pollInterval,
                )
            }
        }

        let firstPageRequest = makeRequest(
            path: "/notifications",
            token: token,
            queryItems: [URLQueryItem(name: "per_page", value: String(Self.threadsPerPage))],
        )

        let (firstPageData, firstPageResponse, firstPageHeaders) = try await send(firstPageRequest)
        try throwIfUnsuccessful(response: firstPageResponse, headers: firstPageHeaders)

        var threads = try decodeThreads(from: firstPageData)
        var nextPageURL = firstPageHeaders.nextPageURL
        var pagesFetched = 1

        while let pageURL = nextPageURL, pagesFetched < Self.pageLimit {
            let pageRequest = makeRequest(url: pageURL, token: token)
            let (pageData, pageResponse, pageHeaders) = try await send(pageRequest)
            try throwIfUnsuccessful(response: pageResponse, headers: pageHeaders)

            threads.append(contentsOf: try decodeThreads(from: pageData))
            nextPageURL = pageHeaders.nextPageURL
            pagesFetched += 1
        }

        return NotificationsResponse(
            threads: threads,
            isUnchanged: false,
            lastModified: firstPageHeaders.lastModified,
            pollInterval: firstPageHeaders.pollInterval,
        )
    }

    /// One page is enough: this only decides which locally-held read threads
    /// still exist, and a thread that has fallen off the first page of the whole
    /// inbox is long past being shown in the panel.
    func fetchEntireInbox(usingToken token: String) async throws -> [NotificationThread] {
        let request = makeRequest(
            path: "/notifications",
            token: token,
            queryItems: [
                URLQueryItem(name: "all", value: "true"),
                URLQueryItem(name: "per_page", value: String(Self.threadsPerPage)),
            ],
        )

        let (data, response, headers) = try await send(request)
        try throwIfUnsuccessful(response: response, headers: headers)

        return try decodeThreads(from: data)
    }

    func markThreadAsRead(threadIdentifier: String, usingToken token: String) async throws {
        let request = makeRequest(path: "/notifications/threads/\(threadIdentifier)", token: token, method: "PATCH")
        let (_, response, headers) = try await send(request)

        try throwIfUnsuccessful(response: response, headers: headers)
    }

    func markThreadAsDone(threadIdentifier: String, usingToken token: String) async throws {
        let request = makeRequest(path: "/notifications/threads/\(threadIdentifier)", token: token, method: "DELETE")
        let (_, response, headers) = try await send(request)

        try throwIfUnsuccessful(response: response, headers: headers)
    }

    func markEverythingAsRead(usingToken token: String) async throws {
        let request = makeRequest(path: "/notifications", token: token, method: "PUT")
        let (_, response, headers) = try await send(request)

        try throwIfUnsuccessful(response: response, headers: headers)
    }

    /// The subject URL is GitHub's own, taken from a thread rather than built
    /// here, so it is sent as given.
    func fetchSubjectStatus(at subjectURL: URL, usingToken token: String) async throws -> SubjectStatus {
        let request = makeRequest(url: subjectURL, token: token)
        let (data, response, headers) = try await send(request)

        try throwIfUnsuccessful(response: response, headers: headers)

        guard let status = try? JSONDecoder().decode(SubjectStatusResponse.self, from: data) else {
            throw GitHubError.malformedResponse
        }

        return status.status
    }

    /// Only the newest page is wanted, and the timeline is oldest first, so a
    /// long one is read from its last page rather than from the start.
    func fetchTimeline(at timelineURL: URL, usingToken token: String) async throws -> [TimelineEvent] {
        var components = URLComponents(url: timelineURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "per_page", value: String(Self.timelineEventsPerPage))]

        let firstPageRequest = makeRequest(url: components?.url ?? timelineURL, token: token)
        let (firstPageData, firstPageResponse, firstPageHeaders) = try await send(firstPageRequest)
        try throwIfUnsuccessful(response: firstPageResponse, headers: firstPageHeaders)

        guard let lastPageURL = firstPageHeaders.lastPageURL else {
            return try decodeTimeline(from: firstPageData)
        }

        let lastPageRequest = makeRequest(url: lastPageURL, token: token)
        let (lastPageData, lastPageResponse, lastPageHeaders) = try await send(lastPageRequest)
        try throwIfUnsuccessful(response: lastPageResponse, headers: lastPageHeaders)

        return try decodeTimeline(from: lastPageData)
    }

    /// - Throws: ``GitHubError/malformedResponse`` when the payload does not decode.
    private func decodeTimeline(from data: Data) throws -> [TimelineEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let events = try? decoder.decode([TimelineEvent].self, from: data) else {
            throw GitHubError.malformedResponse
        }

        return events
    }

    /// - Throws: ``GitHubError/malformedResponse`` when the payload does not decode.
    private func decodeThreads(from data: Data) throws -> [NotificationThread] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let threads = try? decoder.decode([NotificationThread].self, from: data) else {
            throw GitHubError.malformedResponse
        }

        return threads
    }
}
