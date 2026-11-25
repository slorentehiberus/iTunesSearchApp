import Foundation
import Testing
@testable import Iberia

@Suite("CachedSongRepository in-flight coalescing", .timeLimit(.minutes(1)))
struct CachedSongRepositoryCoalescingTests {
    private let query = SearchQuery("queen")!
    private let songs = [Song.fixture(id: 1), Song.fixture(id: 2)]

    private func makeSUT() -> (sut: CachedSongRepository, gate: GatedSongRepository, cache: SongMemoryCache) {
        let gate = GatedSongRepository()
        let cache = SongMemoryCache(clock: ManualCacheClock())
        return (CachedSongRepository(base: gate, cache: cache), gate, cache)
    }

    @Test("Identical concurrent searches share one fetch and all receive its result")
    func coalescesIdenticalSearches() async throws {
        let (sut, gate, cache) = makeSUT()
        let query = query

        let tasks = (0..<3).map { _ in
            Task { try await sut.searchSongs(matching: query) }
        }
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 3 })
        // The shared fetch runs in its own task: wait until it has actually reached the base.
        #expect(await waitUntil { await gate.callCount == 1 })

        await gate.release(with: songs)

        for task in tasks {
            let result = try await task.value
            #expect(result == songs)
        }
        #expect(await gate.callCount == 1)
        #expect(await cache.cachedSongs(for: query) == songs)
        #expect(await sut.inFlightWaiterCount(for: query) == 0)
    }

    @Test("Different queries are not coalesced")
    func differentQueriesAreNotCoalesced() async throws {
        let (sut, gate, _) = makeSUT()
        let other = SearchQuery("abba")!
        let query = query

        let first = Task { try await sut.searchSongs(matching: query) }
        let second = Task { try await sut.searchSongs(matching: other) }
        #expect(await waitUntil { await gate.callCount == 2 })

        await gate.release(with: songs)
        _ = try await first.value
        _ = try await second.value

        #expect(await gate.callCount == 2)
    }

    @Test("A failed shared fetch fails every waiter and is not cached; the next search retries")
    func sharedFailureReachesAllWaiters() async throws {
        let (sut, gate, cache) = makeSUT()
        let query = query

        let tasks = (0..<2).map { _ in
            Task { try await sut.searchSongs(matching: query) }
        }
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 2 })
        #expect(await waitUntil { await gate.callCount == 1 })

        await gate.fail(with: SearchError.serverError)

        for task in tasks {
            await #expect(throws: SearchError.serverError) {
                try await task.value
            }
        }
        #expect(await cache.cachedSongs(for: query) == nil)
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 0 })

        let retry = Task { try await sut.searchSongs(matching: query) }
        #expect(await waitUntil { await gate.callCount == 2 })
        await gate.release(with: songs)
        #expect(try await retry.value == songs)
    }

    @Test("Cancelling one of several callers does not cancel the shared fetch")
    func cancellingOneCallerKeepsFetchAlive() async throws {
        let (sut, gate, _) = makeSUT()
        let query = query

        let cancelled = Task { try await sut.searchSongs(matching: query) }
        let survivor = Task { try await sut.searchSongs(matching: query) }
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 2 })
        #expect(await waitUntil { await gate.callCount == 1 })

        cancelled.cancel()
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 1 })
        #expect(await gate.wasCancelled == false)

        await gate.release(with: songs)

        let result = try await survivor.value
        #expect(result == songs)
        await #expect(throws: CancellationError.self) {
            try await cancelled.value
        }
        #expect(await gate.callCount == 1)
    }

    @Test("Cancelling the only caller cancels the fetch, caches nothing and lets the next search start fresh")
    func cancellingLastCallerCancelsFetch() async throws {
        let (sut, gate, cache) = makeSUT()
        let query = query

        let only = Task { try await sut.searchSongs(matching: query) }
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 1 })
        #expect(await waitUntil { await gate.callCount == 1 })

        only.cancel()

        await #expect(throws: CancellationError.self) {
            try await only.value
        }
        #expect(await gate.wasCancelled)
        #expect(await cache.cachedSongs(for: query) == nil)
        #expect(await waitUntil { await sut.inFlightWaiterCount(for: query) == 0 })

        let fresh = Task { try await sut.searchSongs(matching: query) }
        #expect(await waitUntil { await gate.callCount == 2 })
        await gate.release(with: songs)
        #expect(try await fresh.value == songs)
    }
}
