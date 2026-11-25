import Testing
@testable import Iberia

@Suite("SongMemoryCache")
struct SongMemoryCacheTests {
    private let query = SearchQuery("queen")!
    private let songs = [Song.fixture(id: 1), Song.fixture(id: 2)]

    @Test("Default TTL is 3 minutes")
    func defaultTTLIsThreeMinutes() {
        #expect(SongMemoryCache.defaultTTL == .seconds(180))
    }

    @Test("Returns nil when nothing is stored")
    func missWhenEmpty() async {
        let sut = SongMemoryCache(clock: ManualCacheClock())

        #expect(await sut.cachedSongs(for: query) == nil)
    }

    @Test("Returns stored songs while the entry is valid")
    func hitWhileValid() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(clock: clock)
        await sut.store(songs, for: query)

        clock.advance(by: .seconds(179) + .milliseconds(999))

        #expect(await sut.cachedSongs(for: query) == songs)
    }

    @Test("Entry expires exactly when the TTL is reached")
    func expiresAtTTL() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(clock: clock)
        await sut.store(songs, for: query)

        clock.advance(by: .seconds(180))

        #expect(await sut.cachedSongs(for: query) == nil)
    }

    @Test("TTL is configurable and can be tested in milliseconds")
    func customTTL() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(ttl: .milliseconds(50), clock: clock)
        await sut.store(songs, for: query)

        clock.advance(by: .milliseconds(49))
        #expect(await sut.cachedSongs(for: query) == songs)

        clock.advance(by: .milliseconds(1))
        #expect(await sut.cachedSongs(for: query) == nil)
    }

    @Test("Storing again refreshes the entry's lifetime")
    func storeRefreshesLifetime() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(clock: clock)
        await sut.store(songs, for: query)
        clock.advance(by: .seconds(170))

        await sut.store([.fixture(id: 9)], for: query)
        clock.advance(by: .seconds(170))

        #expect(await sut.cachedSongs(for: query) == [.fixture(id: 9)])
    }

    @Test("Reading an entry does not extend its lifetime")
    func readingDoesNotExtendTTL() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(clock: clock)
        await sut.store(songs, for: query)

        clock.advance(by: .seconds(170))
        _ = await sut.cachedSongs(for: query)
        clock.advance(by: .seconds(10))

        #expect(await sut.cachedSongs(for: query) == nil)
    }

    @Test("Storing purges every expired entry, even those that were never read again")
    func storePurgesExpiredEntries() async {
        let clock = ManualCacheClock()
        let sut = SongMemoryCache(clock: clock)
        await sut.store(songs, for: SearchQuery("a")!)
        await sut.store(songs, for: SearchQuery("b")!)
        clock.advance(by: .seconds(180))

        await sut.store(songs, for: SearchQuery("c")!)

        #expect(await sut.entryCount == 1)
    }

    @Test("Equivalent raw queries share one entry; different queries do not")
    func entriesAreKeyedByNormalizedQuery() async {
        let sut = SongMemoryCache(clock: ManualCacheClock())
        await sut.store(songs, for: SearchQuery("  QUEEN ")!)

        #expect(await sut.cachedSongs(for: query) == songs)
        #expect(await sut.cachedSongs(for: SearchQuery("queen live")!) == nil)
    }
}
