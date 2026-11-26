struct DefaultSearchSongsUseCase: SearchSongsUseCase {
    private let repository: any SongRepository

    init(repository: any SongRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [Song] {
        guard let searchQuery = SearchQuery(query) else { return [] }

        let songs: [Song]
        do {
            songs = try await repository.searchSongs(matching: searchQuery)
        } catch let error as CancellationError {
            throw error
        } catch let error as SearchError {
            throw error
        } catch {
            throw SearchError.unknown(String(describing: error))
        }

        var seen = Set<Song.ID>()
        return songs.filter { seen.insert($0.id).inserted }
    }
}
