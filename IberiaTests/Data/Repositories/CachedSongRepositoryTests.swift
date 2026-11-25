import Foundation
import Testing
@testable import Iberia

@Suite("CachedSongRepository")
struct CachedSongRepositoryTests {
    private let query = SearchQuery("queen")!
    private let songs = [Song.fixture(id: 1), Song.fixture(id: 2)]

    private struct Harness {
        let sut: CachedSongRepository
        let base: SongRepositorySpy
        let cache: SongMemoryCache
        let clock: ManualCacheClock
    }

    private func makeHarness(_ behavior: SongRepositorySpy.Behavior) -> Harness {
        let base = SongRepositorySpy(behavior: behavior)
        let clock = ManualCacheClock()
        let cache = SongMemoryCache(clock: clock)
        return Harness(
            sut: CachedSongRepository(base: base, cache: cache),
            base: base,
            cache: cache,
            clock: clock
        )
    }

    // MARK: - Cache policy

    @Test("Two searches with the same query call the decorated repository once")
    func cacheHitSkipsBase() async throws {
        let h = makeHarness(.success(songs))

        let first = try await h.sut.searchSongs(matching: query)
        let second = try await h.sut.searchSongs(matching: query)

        #expect(first == songs)
        #expect(second == songs)
        #expect(await h.base.callCount == 1)
    }

    @Test("Equivalent raw queries share the cache entry")
    func equivalentQueriesShareCache() async throws {
        let h = makeHarness(.success(songs))

        _ = try await h.sut.searchSongs(matching: SearchQuery("Queen")!)
        _ = try await h.sut.searchSongs(matching: SearchQuery("  queen  ")!)

        #expect(await h.base.callCount == 1)
    }

    @Test("Different queries each reach the decorated repository")
    func differentQueriesReachBase() async throws {
        let h = makeHarness(.success(songs))

        _ = try await h.sut.searchSongs(matching: SearchQuery("queen")!)
        _ = try await h.sut.searchSongs(matching: SearchQuery("abba")!)

        #expect(await h.base.callCount == 2)
    }

    @Test("After the 3-minute TTL the base is called again and the cache is refreshed")
    func expiredEntryRefetchesAndUpdatesCache() async throws {
        let first = [Song.fixture(id: 1)]
        let second = [Song.fixture(id: 2)]
        let h = makeHarness(.script([.success(first), .success(second)]))

        let initial = try await h.sut.searchSongs(matching: query)
        h.clock.advance(by: .seconds(179))
        let stillCached = try await h.sut.searchSongs(matching: query)
        #expect(await h.base.callCount == 1)

        h.clock.advance(by: .seconds(1))
        let refreshed = try await h.sut.searchSongs(matching: query)
        let cachedAgain = try await h.sut.searchSongs(matching: query)

        #expect(initial == first)
        #expect(stillCached == first)
        #expect(refreshed == second)
        #expect(cachedAgain == second)
        #expect(await h.base.callCount == 2)
    }

    // MARK: - Errors and cancellation

    @Test("Errors propagate unchanged and are not cached")
    func errorsAreNotCached() async throws {
        let h = makeHarness(.script([.failure(SearchError.serverError), .success(songs)]))

        await #expect(throws: SearchError.serverError) {
            try await h.sut.searchSongs(matching: query)
        }
        #expect(await h.cache.cachedSongs(for: query) == nil)

        let retry = try await h.sut.searchSongs(matching: query)
        #expect(retry == songs)
        #expect(await h.base.callCount == 2)
    }

    @Test("A CancellationError from the base propagates and nothing is cached")
    func baseCancellationIsNotCached() async {
        let h = makeHarness(.failure(CancellationError()))

        await #expect(throws: CancellationError.self) {
            try await h.sut.searchSongs(matching: query)
        }
        #expect(await h.cache.cachedSongs(for: query) == nil)
    }

    @Test("A caller cancelled before the result arrives gets CancellationError, not songs")
    func cancelledCallerDoesNotReceiveSongs() async {
        let h = makeHarness(.success(songs))
        let query = query

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await h.sut.searchSongs(matching: query)
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    // MARK: - Composition with the real remote stack

    @Test("Full stack: the second identical search does not reach the HTTP client")
    func fullStackCacheHit() async throws {
        let http = HTTPClientSpy(steps: [.response(ITunesFixtures.response(trackIDs: [1, 2]))])
        let sut = CachedSongRepository(
            base: RemoteSongRepository(dataSource: ITunesSongRemoteDataSource(httpClient: http)),
            cache: SongMemoryCache(clock: ManualCacheClock())
        )

        let first = try await sut.searchSongs(matching: query)
        let second = try await sut.searchSongs(matching: query)

        #expect(first.map(\.id) == [1, 2])
        #expect(first == second)
        #expect(await http.callCount == 1)
    }
}
