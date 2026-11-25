/// Thread-safe in-memory cache with a time-to-live per entry.
///
/// - Entries expire after `ttl` (an entry that has lived exactly `ttl` is already expired).
/// - An expired entry is never returned, and every `store` purges all expired entries,
///   so queries that are never asked again do not stay in memory forever.
actor SongMemoryCache: SongCache {
    static let defaultTTL: Duration = .seconds(180)

    private struct Entry {
        let songs: [Song]
        let storedAt: Duration
    }

    private let ttl: Duration
    private let clock: any CacheClock
    private var entries: [SearchQuery: Entry] = [:]

    init(ttl: Duration = SongMemoryCache.defaultTTL, clock: any CacheClock = SystemCacheClock()) {
        self.ttl = ttl
        self.clock = clock
    }

    /// Number of stored entries, expired ones included until they are purged. Exposed for tests.
    var entryCount: Int { entries.count }

    func cachedSongs(for query: SearchQuery) -> [Song]? {
        guard let entry = entries[query] else { return nil }
        guard !isExpired(entry) else {
            entries[query] = nil
            return nil
        }
        return entry.songs
    }

    func store(_ songs: [Song], for query: SearchQuery) {
        purgeExpiredEntries()
        entries[query] = Entry(songs: songs, storedAt: clock.now)
    }

    // MARK: - Private

    private func isExpired(_ entry: Entry) -> Bool {
        clock.now - entry.storedAt >= ttl
    }

    private func purgeExpiredEntries() {
        entries = entries.filter { !isExpired($0.value) }
    }
}
