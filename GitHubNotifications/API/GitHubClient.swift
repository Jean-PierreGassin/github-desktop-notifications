import Foundation

protocol GitHubAPI: Sendable {
    /// Confirms a token works and reports which scopes GitHub granted it.
    ///
    /// - Throws: ``GitHubError`` when the token is rejected, the network fails,
    ///   or GitHub returns something unreadable.
    func fetchAuthenticatedUser(usingToken token: String) async throws -> AuthenticatedUser

    /// Fetches the unread inbox, sending `If-Modified-Since` so an unchanged
    /// inbox costs nothing against the rate limit.
    ///
    /// - Throws: ``GitHubError`` when GitHub rejects the request or the network fails.
    func fetchNotifications(usingToken token: String, since lastModified: String?) async throws -> NotificationsResponse

    /// - Throws: ``GitHubError`` when GitHub rejects the request or the network fails.
    func markThreadAsRead(threadIdentifier: String, usingToken token: String) async throws

    /// - Throws: ``GitHubError`` when GitHub rejects the request or the network fails.
    func markThreadAsDone(threadIdentifier: String, usingToken token: String) async throws

    /// - Throws: ``GitHubError`` when GitHub rejects the request or the network fails.
    func markEverythingAsRead(usingToken token: String) async throws
}

struct GitHubClient: GitHubAPI {
    private static let baseURL = URL(string: "https://api.github.com")!
    private static let apiVersion = "2022-11-28"

    private let session: URLSession

    /// The client does its own conditional requests with `If-Modified-Since`, so
    /// it needs an uncached session. `URLSession.shared` keeps a disk cache and
    /// will happily replay a stale inbox, which looks exactly like notifications
    /// never arriving.
    init(session: URLSession = GitHubClient.makeUncachedSession()) {
        self.session = session
    }

    static func makeUncachedSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil

        return URLSession(configuration: configuration)
    }

    func fetchAuthenticatedUser(usingToken token: String) async throws -> AuthenticatedUser {
        let request = makeRequest(path: "/user", token: token)
        let (data, response, headers) = try await send(request)

        try throwIfUnsuccessful(response: response, headers: headers)

        guard let account = try? JSONDecoder().decode(GitHubAccount.self, from: data) else {
            throw GitHubError.malformedResponse
        }

        return AuthenticatedUser(account: account, grantedScopes: headers.grantedScopes)
    }

    func makeRequest(
        path: String,
        token: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        lastModified: String? = nil,
    ) -> URLRequest {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return makeRequest(url: components.url!, token: token, method: method, lastModified: lastModified)
    }

    func makeRequest(
        url: URL,
        token: String,
        method: String = "GET",
        lastModified: String? = nil,
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")

        return request
    }

    /// - Throws: ``GitHubError/offline`` or ``GitHubError/transportFailure(description:)``
    ///   when the request never reaches GitHub.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse, ResponseHeaders) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.malformedResponse
            }

            return (data, httpResponse, ResponseHeaders(httpResponse))
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw GitHubError.offline
        } catch let error as URLError {
            throw GitHubError.transportFailure(description: error.localizedDescription)
        }
    }

    /// - Throws: ``GitHubError`` matching the status code GitHub returned.
    func throwIfUnsuccessful(response: HTTPURLResponse, headers: ResponseHeaders) throws {
        switch response.statusCode {
        case 200 ..< 300, 304:
            return
        case 401:
            throw GitHubError.invalidToken
        case 403, 429:
            throw rateLimitError(headers: headers, statusCode: response.statusCode)
        default:
            throw GitHubError.serverFailure(statusCode: response.statusCode)
        }
    }

    private var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

        return "GitHubNotifications/\(version) (macOS menu bar app)"
    }

    private func rateLimitError(headers: ResponseHeaders, statusCode: Int) -> GitHubError {
        if let retryAfter = headers.retryAfter {
            return .askedToSlowDown(retryAfter: retryAfter)
        }

        if headers.rateLimitRemaining == 0, let resetAt = headers.rateLimitResetAt {
            return .rateLimited(resetAt: resetAt)
        }

        return .serverFailure(statusCode: statusCode)
    }
}
