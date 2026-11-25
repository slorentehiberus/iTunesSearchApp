@testable import Iberia

/// Test double for `SearchSongsUseCase`. Records every call and lets the test decide how and when each one ends.
actor SearchSongsUseCaseSpy: SearchSongsUseCase {
    enum Behavior: Sendable {
        /// Answers immediately with the n-th result; the last one repeats.
        case script([Result<[Song], any Error>])
        /// Each call waits until the test releases it; cancelling the task ends it with `CancellationError`.
        case gated
        /// Like `gated`, but ignores cancellation, simulating a use case that returns a stale result late.
        case gatedIgnoringCancellation
    }

    private let behavior: Behavior
    private var pending: [Int: CheckedContinuation<[Song], any Error>] = [:]
    private(set) var receivedQueries: [String] = []
    private(set) var cancelledCalls: Set<Int> = []

    var callCount: Int { receivedQueries.count }

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func execute(query: String) async throws -> [Song] {
        let call = receivedQueries.count
        receivedQueries.append(query)

        switch behavior {
        case .script(let results):
            return try results[min(call, results.count - 1)].get()
        case .gated:
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    pending[call] = continuation
                }
            } onCancel: {
                Task { await self.cancel(call: call) }
            }
        case .gatedIgnoringCancellation:
            return try await withCheckedThrowingContinuation { continuation in
                pending[call] = continuation
            }
        }
    }

    func release(call: Int, with songs: [Song]) {
        pending.removeValue(forKey: call)?.resume(returning: songs)
    }

    func fail(call: Int, with error: any Error) {
        pending.removeValue(forKey: call)?.resume(throwing: error)
    }

    private func cancel(call: Int) {
        cancelledCalls.insert(call)
        pending.removeValue(forKey: call)?.resume(throwing: CancellationError())
    }
}
