/// Thread-safe in-memory cache with a time-to-live per entry and a bounded size.
///
/// - Entries expire after `ttl` (an entry that has lived exactly `ttl` is already expired).
/// - Expired entries are purged on every `store`.
/// - When the cache exceeds `maxEntries`, the least recently used entries are evicted.
///   Reading an entry counts as a use; it does not extend its lifetime.
actor SongMemoryCache: SongCache {
    static let defaultTTL: Duration = .seconds(180)
    static let defaultMaxEntries = 50

    private struct Entry {
        let songs: [Song]
        let storedAt: Duration
        var lastAccess: UInt64
    }

    private let ttl: Duration
    private let maxEntries: Int
    private let clock: any CacheClock
    private var entries: [SearchQuery: Entry] = [:]
    private var accessCounter: UInt64 = 0

    init(
        ttl: Duration = SongMemoryCache.defaultTTL,
        maxEntries: Int = SongMemoryCache.defaultMaxEntries,
        clock: any CacheClock = SystemCacheClock()
    ) {
        precondition(maxEntries >= 1, "maxEntries must be at least 1")
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.clock = clock
    }

    /// Number of stored entries, expired ones included until they are purged. Exposed for tests.
    var entryCount: Int { entries.count }

    func cachedSongs(for query: SearchQuery) -> [Song]? {
        guard var entry = entries[query] else { return nil }
        guard !isExpired(entry) else {
            entries[query] = nil
            return nil
        }
        entry.lastAccess = nextAccessStamp()
        entries[query] = entry
        return entry.songs
    }

    func store(_ songs: [Song], for query: SearchQuery) {
        purgeExpiredEntries()
        entries[query] = Entry(songs: songs, storedAt: clock.now, lastAccess: nextAccessStamp())
        evictLeastRecentlyUsedBeyondLimit()
    }

    // MARK: - Private

    private func isExpired(_ entry: Entry) -> Bool {
        clock.now - entry.storedAt >= ttl
    }

    private func nextAccessStamp() -> UInt64 {
        accessCounter += 1
        return accessCounter
    }

    private func purgeExpiredEntries() {
        entries = entries.filter { !isExpired($0.value) }
    }

    private func evictLeastRecentlyUsedBeyondLimit() {
        while entries.count > maxEntries,
              let leastRecent = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            entries[leastRecent] = nil
        }
    }
}
