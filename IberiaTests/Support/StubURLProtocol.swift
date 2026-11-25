import Foundation
import os

/// Intercepts a `URLSession` so tests exercise the real session without touching the network.
/// Behaviors are registered per host, so tests running in parallel never interfere with each other.
final class StubURLProtocol: URLProtocol {
    enum Behavior: Sendable {
        case respond(statusCode: Int, data: Data)
        /// A response that is not an `HTTPURLResponse`.
        case respondNotHTTP(data: Data)
        case fail(URLError.Code)
        /// Never answers: lets a test cancel a request that is genuinely in flight.
        case hang
    }

    struct Events: Sendable, Equatable {
        var started = 0
        /// Counts requests the session abandoned (cancelled or finished).
        var stopped = 0
    }

    private struct State {
        var behaviors: [String: Behavior] = [:]
        var events: [String: Events] = [:]
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// A session that routes every request through this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func register(_ behavior: Behavior, forHost host: String) {
        state.withLock {
            $0.behaviors[host] = behavior
            $0.events[host] = Events()
        }
    }

    static func events(forHost host: String) -> Events {
        state.withLock { $0.events[host] ?? Events() }
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let behavior = Self.state.withLock { state -> Behavior? in
            state.events[host, default: Events()].started += 1
            return state.behaviors[host]
        }

        switch behavior {
        case .respond(let statusCode, let data):
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .respondNotHTTP(let data):
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .fail(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang, .none:
            break
        }
    }

    override func stopLoading() {
        guard let host = request.url?.host else { return }
        Self.state.withLock { $0.events[host, default: Events()].stopped += 1 }
    }
}
