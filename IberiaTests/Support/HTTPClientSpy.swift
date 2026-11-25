import Foundation
@testable import Iberia

/// Test double for `HTTPClientProtocol`: counts calls and plays back scripted steps.
/// When the script runs out, the last step repeats.
actor HTTPClientSpy: HTTPClientProtocol {
    enum Step: Sendable {
        case response(Data, statusCode: Int = 200)
        case failure(any Error)
        /// Cancels the task that is performing the request, then answers successfully.
        case cancelCallerThenRespond(Data)
    }

    private var steps: [Step]
    private(set) var requestedURLs: [URL] = []

    var callCount: Int { requestedURLs.count }

    init(steps: [Step]) {
        precondition(!steps.isEmpty)
        self.steps = steps
    }

    func get(_ url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
        requestedURLs.append(url)
        let step = steps.count > 1 ? steps.removeFirst() : steps[0]

        switch step {
        case .response(let data, let statusCode):
            return (data, Self.httpResponse(url: url, statusCode: statusCode))
        case .failure(let error):
            throw error
        case .cancelCallerThenRespond(let data):
            withUnsafeCurrentTask { $0?.cancel() }
            return (data, Self.httpResponse(url: url, statusCode: 200))
        }
    }

    private static func httpResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
