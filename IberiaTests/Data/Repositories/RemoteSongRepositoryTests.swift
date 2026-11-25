import Testing
@testable import Iberia

@Suite("RemoteSongRepository")
struct RemoteSongRepositoryTests {

    private struct DataSourceStub: SongRemoteDataSource {
        let result: Result<[Song], any Error>

        func fetchSongs(for query: SearchQuery) async throws -> [Song] {
            try result.get()
        }
    }

    @Test("Delegates to the remote data source and returns its songs")
    func returnsDataSourceSongs() async throws {
        let songs = [Song.fixture(id: 1)]
        let sut = RemoteSongRepository(dataSource: DataSourceStub(result: .success(songs)))

        let result = try await sut.searchSongs(matching: SearchQuery("queen")!)

        #expect(result == songs)
    }

    @Test("Propagates data source errors unchanged")
    func propagatesErrors() async {
        let sut = RemoteSongRepository(dataSource: DataSourceStub(result: .failure(SearchError.serverError)))

        await #expect(throws: SearchError.serverError) {
            try await sut.searchSongs(matching: SearchQuery("queen")!)
        }
    }
}
