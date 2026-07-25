import Foundation

/// The response headers the polling loop depends on, parsed once at the edge so
/// nothing downstream deals in raw strings.
struct ResponseHeaders: Sendable {
    let grantedScopes: Set<TokenScope>
    let lastModified: String?
    let pollInterval: TimeInterval?
    let rateLimitRemaining: Int?
    let rateLimitResetAt: Date?
    let retryAfter: TimeInterval?
    let nextPageURL: URL?

    init(_ response: HTTPURLResponse) {
        nextPageURL = Self.parseNextPageURL(from: response.value(forHTTPHeaderField: "Link"))
        let scopesHeader = response.value(forHTTPHeaderField: "X-OAuth-Scopes") ?? ""
        let resetTimestamp = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init)

        grantedScopes = TokenScope.parse(headerValue: scopesHeader)
        lastModified = response.value(forHTTPHeaderField: "Last-Modified")
        pollInterval = response.value(forHTTPHeaderField: "X-Poll-Interval").flatMap(TimeInterval.init)
        rateLimitRemaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init)
        rateLimitResetAt = resetTimestamp.map { Date(timeIntervalSince1970: $0) }
        retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
    }

    /// Pulls the `rel="next"` URL out of a `Link` header such as
    /// `<https://api.github.com/notifications?page=2>; rel="next", <…>; rel="last"`.
    static func parseNextPageURL(from linkHeader: String?) -> URL? {
        guard let linkHeader else {
            return nil
        }

        let links = linkHeader.split(separator: ",")

        for link in links where link.contains("rel=\"next\"") {
            guard let start = link.firstIndex(of: "<"), let end = link.firstIndex(of: ">") else {
                continue
            }

            let address = link[link.index(after: start) ..< end]

            return URL(string: String(address))
        }

        return nil
    }
}
