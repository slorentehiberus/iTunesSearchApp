import Domain
import Foundation

/// Minimal HTTP abstraction. It returns the raw result and throws the transport's raw errors;
/// translating them into domain errors is the repository's job.
public protocol HTTPClientProtocol: Sendable {
    func get(_ url: URL) async throws -> (data: Data, response: HTTPURLResponse)
}
