@testable import Iberia

/// Test double: records the received queries and responds according to `behavior`.
/// It is an `actor` so it is `Sendable` without locks or `@unchecked`.
actor SongRepositorySpy: SongRepository {
    enum Behavior: Sendable {
        case success([Song])
        case failure(any Error)
        /// Plays the results in order, one per call; the last one repeats.
        case script([Result<[Song], any Error>])
        /// Waits until the task is cancelled (no real long waits in tests).
        case suspendUntilCancelled
    }

    private let behavior: Behavior
    private var scriptIndex = 0
    private(set) var receivedQueries: [SearchQuery] = []

    var callCount: Int { receivedQueries.count }

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        receivedQueries.append(query)
        switch behavior {
        case .success(let songs):
            return songs
        case .failure(let error):
            throw error
        case .script(let results):
            let result = results[min(scriptIndex, results.count - 1)]
            scriptIndex += 1
            return try result.get()
        case .suspendUntilCancelled:
            try await Task.sleep(for: .seconds(60))
            return []
        }
    }
}
