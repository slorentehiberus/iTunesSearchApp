/// Source of songs. Defined in Domain, implemented in Data (DIP).
/// A single read operation (ISP): caching is an internal detail of the implementation.
protocol SongRepository: Sendable {
    func searchSongs(matching query: SearchQuery) async throws -> [Song]
}
