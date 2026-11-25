@testable import Iberia

/// Test double whose calls stay suspended until the test releases, fails or cancels them.
/// It makes concurrency scenarios deterministic: the test decides when the "network" answers.
actor GatedSongRepository: SongRepository {
    private var pending: [CheckedContinuation<[Song], any Error>] = []
    private(set) var callCount = 0
    /// `true` once a suspended call has been cancelled.
    private(set) var wasCancelled = false

    func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        callCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelPending() }
        }
    }

    func release(with songs: [Song]) {
        let waiting = pending
        pending = []
        waiting.forEach { $0.resume(returning: songs) }
    }

    func fail(with error: any Error) {
        let waiting = pending
        pending = []
        waiting.forEach { $0.resume(throwing: error) }
    }

    private func cancelPending() {
        wasCancelled = true
        fail(with: CancellationError())
    }
}
