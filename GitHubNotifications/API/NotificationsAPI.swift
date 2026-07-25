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

    func fetchNotifications(usingToken token: String, since lastModified: String?) async throws -> NotificationsResponse {
        let firstPageRequest = makeRequest(
            path: "/notifications",
            token: token,
            queryItems: [URLQueryItem(name: "per_page", value: String(Self.threadsPerPage))],
            lastModified: lastModified,
        )

        let (firstPageData, firstPageResponse, firstPageHeaders) = try await send(firstPageRequest)
        try throwIfUnsuccessful(response: firstPageResponse, headers: firstPageHeaders)

        guard firstPageResponse.statusCode != 304 else {
            return NotificationsResponse(
                threads: [],
                isUnchanged: true,
                lastModified: lastModified,
                pollInterval: firstPageHeaders.pollInterval,
            )
        }

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
