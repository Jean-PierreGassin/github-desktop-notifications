import Foundation

/// Serves avatar bytes to `AvatarCache` tests.
///
/// A class of its own rather than a second user of ``StubURLProtocol``: the
/// handler and the request log are class-level state, and suites run in
/// parallel, so sharing one class means one suite answering another's requests.
final class StubAvatarProtocol: URLProtocol {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (statusCode: Int, body: Data))?
    nonisolated(unsafe) static var receivedRequests: [URLRequest] = []

    static func makeSession() -> URLSession {
        receivedRequests = []

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAvatarProtocol.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.receivedRequests.append(request)

        let stubbed = Self.respond?(request) ?? (statusCode: 200, body: Data())
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbed.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:],
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stubbed.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
