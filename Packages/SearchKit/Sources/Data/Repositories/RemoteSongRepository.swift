import Domain

/// Exposes a remote data source through the Domain `SongRepository` contract.
/// It is the decorated "base" of `CachedSongRepository`.
public struct RemoteSongRepository: SongRepository {
    private let dataSource: any SongRemoteDataSource

    public init(dataSource: any SongRemoteDataSource) {
        self.dataSource = dataSource
    }

    public func searchSongs(matching query: SearchQuery) async throws -> [Song] {
        try await dataSource.fetchSongs(for: query)
    }
}
