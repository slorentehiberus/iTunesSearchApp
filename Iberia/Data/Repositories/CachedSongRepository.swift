import Foundation

/// Decorator that adds caching and in-flight request coalescing to any `SongRepository`.
///
/// - A non-expired cache entry is returned with NO call to the decorated repository.
/// - Identical queries that arrive while one is already being fetched share that single fetch.
/// - Successful results are cached; errors and cancelled requests never are.
/// - The shared fetch is cancelled only when every caller waiting for it has been cancelled.
actor CachedSongRepository: SongRepository {
    private struct Flight {
        let id: UUID
        let task: Task<[Song], any Error>
        var waiters: Int
    }

    private let base: any SongRepository
    private let cache: any SongCache
    private var flights: [SearchQuery: Flight] = [:]

    init(base: any SongRepository, cache: any SongCache) {
        self.base = base
        self.cache = cache
    }

    func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        if let cached = await cache.cachedSongs(for: query) {
            return cached
        }

        let (flightID, task) = joinFlight(for: query)
        let songs = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.leaveFlight(id: flightID, for: query) }
        }

        // The shared fetch may have finished for the other callers; this one is cancelled anyway.
        try Task.checkCancellation()
        return songs
    }

    /// Number of callers currently waiting for the fetch of `query`. Exposed for tests and diagnostics.
    func inFlightWaiterCount(for query: SearchQuery) -> Int {
        flights[query]?.waiters ?? 0
    }

    // MARK: - Flights

    /// Joins the active fetch for `query` or starts a new one. Synchronous on purpose:
    /// there is no suspension point between checking and registering, so two callers can never both start one.
    private func joinFlight(for query: SearchQuery) -> (id: UUID, task: Task<[Song], any Error>) {
        if var flight = flights[query] {
            flight.waiters += 1
            flights[query] = flight
            return (flight.id, flight.task)
        }

        let id = UUID()
        let base = base
        // Detached: the fetch must not inherit any caller's cancellation or run on this actor.
        let task = Task<[Song], any Error>.detached {
            do {
                let songs = try await base.searchSongs(matching: query)
                try Task.checkCancellation()
                await self.finishFlight(id: id, for: query, songs: songs)
                return songs
            } catch {
                await self.finishFlight(id: id, for: query, songs: nil)
                throw error
            }
        }
        flights[query] = Flight(id: id, task: task, waiters: 1)
        return (id, task)
    }

    private func leaveFlight(id: UUID, for query: SearchQuery) {
        guard var flight = flights[query], flight.id == id else { return }
        flight.waiters -= 1
        if flight.waiters <= 0 {
            // Nobody is waiting any more: stop the fetch and let the next search start a fresh one.
            flight.task.cancel()
            flights[query] = nil
        } else {
            flights[query] = flight
        }
    }

    /// Caches the result (only if this flight is still the registered one) and unregisters it.
    private func finishFlight(id: UUID, for query: SearchQuery, songs: [Song]?) async {
        guard flights[query]?.id == id else { return }
        if let songs {
            await cache.store(songs, for: query)
        }
        if flights[query]?.id == id {
            flights[query] = nil
        }
    }
}
