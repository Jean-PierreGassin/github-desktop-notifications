import Foundation

/// Intercepts requests so client tests never touch the network.
///
/// Tests run serially, so a plain static handler is safe here.
final class StubURLProtocol: URLProtocol {
    struct StubbedResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: String

        init(statusCode: Int = 200, headers: [String: String] = [:], body: String = "[]") {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }
    }

    nonisolated(unsafe) static var respond: ((URLRequest) -> StubbedResponse)?
    nonisolated(unsafe) static var receivedRequests: [URLRequest] = []

    static func makeSession() -> URLSession {
        receivedRequests = []

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.receivedRequests.append(request)

        let stubbed = Self.respond?(request) ?? StubbedResponse()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbed.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stubbed.headers,
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stubbed.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
