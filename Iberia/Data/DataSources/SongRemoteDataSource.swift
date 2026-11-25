/// Fetches songs from a remote service. Knows about transport and wire formats, nothing about caching.
protocol SongRemoteDataSource: Sendable {
    /// - Throws: `CancellationError` if the task is cancelled; `SearchError` for any other failure.
    func fetchSongs(for query: SearchQuery) async throws -> [Song]
}
