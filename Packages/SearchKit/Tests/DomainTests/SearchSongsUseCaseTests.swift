import Testing
@testable import Domain
@testable import TestSupport

@Suite("DefaultSearchSongsUseCase")
struct SearchSongsUseCaseTests {

    @Test("Returns results deduplicated by id, keeping the original order")
    func returnsDeduplicatedResultsInOriginalOrder() async throws {
        let a = Song.fixture(id: 1, title: "A")
        let b = Song.fixture(id: 2, title: "B")
        let duplicateOfA = Song.fixture(id: 1, title: "A (other version)")
        let c = Song.fixture(id: 3, title: "C")
        let spy = SongRepositorySpy(behavior: .success([a, b, duplicateOfA, c, b]))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        let result = try await sut.execute(query: "queen")

        #expect(result == [a, b, c])
    }

    @Test("Sends the normalized query to the repository")
    func sendsNormalizedQueryToRepository() async throws {
        let spy = SongRepositorySpy(behavior: .success([]))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        _ = try await sut.execute(query: "  Bohemian   RHAPSODY ")

        let received = await spy.receivedQueries
        #expect(received.map(\.text) == ["bohemian rhapsody"])
    }

    @Test("Empty or whitespace-only query returns [] without calling the repository", arguments: ["", " ", "   ", "\n\t "])
    func invalidQueryReturnsEmptyWithoutCallingRepository(query: String) async throws {
        let spy = SongRepositorySpy(behavior: .success([.fixture(id: 1)]))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        let result = try await sut.execute(query: query)

        #expect(result.isEmpty)
        #expect(await spy.receivedQueries.isEmpty)
    }

    @Test("Propagates repository SearchErrors unchanged")
    func propagatesSearchError() async {
        let spy = SongRepositorySpy(behavior: .failure(SearchError.networkUnavailable))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        await #expect(throws: SearchError.networkUnavailable) {
            try await sut.execute(query: "queen")
        }
    }

    @Test("Maps non-domain errors to SearchError.unknown keeping their description")
    func mapsForeignErrorsToUnknown() async {
        struct ForeignError: Error {}
        let spy = SongRepositorySpy(behavior: .failure(ForeignError()))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        await #expect {
            try await sut.execute(query: "queen")
        } throws: { error in
            guard case SearchError.unknown(let description) = error else { return false }
            return description.contains("ForeignError")
        }
    }

    @Test("A repository CancellationError propagates without being wrapped")
    func propagatesCancellationErrorFromRepository() async {
        let spy = SongRepositorySpy(behavior: .failure(CancellationError()))
        let sut = DefaultSearchSongsUseCase(repository: spy)

        await #expect(throws: CancellationError.self) {
            try await sut.execute(query: "queen")
        }
    }

    @Test("Cancelling the in-flight task ends with CancellationError")
    func cancellingTaskThrowsCancellationError() async {
        let spy = SongRepositorySpy(behavior: .suspendUntilCancelled)
        let sut = DefaultSearchSongsUseCase(repository: spy)

        let task = Task { try await sut.execute(query: "queen") }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
