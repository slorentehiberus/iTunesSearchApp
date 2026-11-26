/// Decorator that adds caching to any `SongRepository`.
///
/// - A non-expired cache entry is returned with NO call to the decorated repository.
/// - Otherwise the decorated repository is queried and the result cached.
/// - Errors and cancelled requests are never cached.
///
/// It holds no state of its own (the cache does), and it awaits the decorated repository directly,
/// so cancelling the calling task cancels the whole chain down to the network request.
struct CachedSongRepository: SongRepository {
    private let base: any SongRepository
    private let cache: any SongCache

    init(base: any SongRepository, cache: any SongCache) {
        self.base = base
        self.cache = cache
    }

    func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        if let cached = await cache.cachedSongs(for: query) {
            return cached
        }
        let songs = try await base.searchSongs(matching: query)
        // A cancelled request must neither be cached nor returned.
        try Task.checkCancellation()

        await cache.store(songs, for: query)
        return songs
    }
}
