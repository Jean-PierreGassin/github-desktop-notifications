import Foundation

protocol ReleaseSource: Sendable {
    /// The newest release worth offering, or `nil` when there is nothing usable
    /// published.
    ///
    /// - Throws: ``GitHubError`` when GitHub rejects the request or the network
    ///   fails.
    func fetchLatestRelease(usingToken token: String?) async throws -> Release?
}

extension GitHubClient: ReleaseSource {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/Jean-PierreGassin/github-desktop-notifications/releases/latest",
    )!

    /// Asked unauthenticated first, for two reasons: an update check should not
    /// spend the user's rate limit, and it has to work while they are signed
    /// out. The unauthenticated limit is sixty an hour per address, so a 403 is
    /// the one case worth spending a token on.
    func fetchLatestRelease(usingToken token: String?) async throws -> Release? {
        var (data, response, headers) = try await send(releaseRequest(token: nil))

        if response.statusCode == 403, let token {
            (data, response, headers) = try await send(releaseRequest(token: token))
        }

        try throwIfUnsuccessful(response: response, headers: headers)

        return Release.decode(from: data)
    }

    private func releaseRequest(token: String?) -> URLRequest {
        guard let token else {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            return request
        }

        return makeRequest(url: Self.latestReleaseURL, token: token)
    }
}
