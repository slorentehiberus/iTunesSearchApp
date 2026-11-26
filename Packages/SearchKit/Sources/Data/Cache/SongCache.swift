import Domain

/// Cache of search results, keyed by normalized query.
public protocol SongCache: Sendable {
    /// Returns the stored songs, or `nil` if there is no entry or it has expired.
    func cachedSongs(for query: SearchQuery) async -> [Song]?
    func store(_ songs: [Song], for query: SearchQuery) async
}
