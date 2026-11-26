/// Exposes a remote data source through the Domain `SongRepository` contract.
/// It is the decorated "base" of `CachedSongRepository`.
struct RemoteSongRepository: SongRepository {
    private let dataSource: any SongRemoteDataSource

    init(dataSource: any SongRemoteDataSource) {
        self.dataSource = dataSource
    }

    func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        try await dataSource.fetchSongs(for: query)
    }
}
