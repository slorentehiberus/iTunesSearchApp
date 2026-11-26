import Foundation
import Testing
@testable import Data
@testable import Domain

@Suite("ITunesSongRemoteDataSource")
struct ITunesSongRemoteDataSourceTests {
    private let query = SearchQuery("queen")!

    private func makeSUT(_ steps: [HTTPClientSpy.Step]) -> (sut: ITunesSongRemoteDataSource, http: HTTPClientSpy) {
        let http = HTTPClientSpy(steps: steps)
        return (ITunesSongRemoteDataSource(httpClient: http), http)
    }

    @Test("Requests the iTunes URL built from the query and maps the songs")
    func fetchesAndMapsSongs() async throws {
        let (sut, http) = makeSUT([.response(ITunesFixtures.response(trackIDs: [1, 2]))])

        let songs = try await sut.fetchSongs(for: query)

        #expect(songs.map(\.id) == [1, 2])
        let urls = await http.requestedURLs
        #expect(urls.map(\.absoluteString) == ["https://itunes.apple.com/search?term=queen&entity=song&limit=25"])
    }

    @Test("URLError(.cancelled) becomes CancellationError")
    func urlErrorCancelledBecomesCancellationError() async {
        let (sut, _) = makeSUT([.failure(URLError(.cancelled))])

        await #expect(throws: CancellationError.self) {
            try await sut.fetchSongs(for: query)
        }
    }

    @Test("A task cancelled before the network call never reaches the network")
    func cancelledBeforeNetwork() async {
        let (sut, http) = makeSUT([.response(ITunesFixtures.response(trackIDs: [1]))])
        let query = query

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.fetchSongs(for: query)
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await http.callCount == 0)
    }

    @Test("A task cancelled during the network call throws instead of returning songs")
    func cancelledAfterNetwork() async {
        let (sut, http) = makeSUT([.cancelCallerThenRespond(ITunesFixtures.response(trackIDs: [1]))])
        let query = query

        let task = Task { try await sut.fetchSongs(for: query) }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await http.callCount == 1)
    }

    @Test("Non-2xx status codes map to SearchError.serverError", arguments: [301, 400, 404, 500, 503])
    func httpErrorMapsToServerError(statusCode: Int) async {
        let (sut, _) = makeSUT([.response(Data(), statusCode: statusCode)])

        await #expect(throws: SearchError.serverError) {
            try await sut.fetchSongs(for: query)
        }
    }

    @Test("Malformed JSON maps to SearchError.invalidResponse")
    func decodingFailureMapsToInvalidResponse() async {
        let (sut, _) = makeSUT([.response(ITunesFixtures.notJSON)])

        await #expect(throws: SearchError.invalidResponse) {
            try await sut.fetchSongs(for: query)
        }
    }

}
