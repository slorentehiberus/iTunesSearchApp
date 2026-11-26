import Foundation
import Testing
@testable import Data
@testable import Domain
@testable import TestSupport

/// Runs the real `URLSessionHTTPClient` against a stubbed `URLProtocol`.
/// This is the only code that talks to the network, so it is also where cancellation is proven end to end.
@Suite("URLSessionHTTPClient", .timeLimit(.minutes(1)))
struct URLSessionHTTPClientTests {

    private func makeClient() -> URLSessionHTTPClient {
        URLSessionHTTPClient(session: StubURLProtocol.makeSession())
    }

    private func url(host: String) throws -> URL {
        try #require(URL(string: "https://\(host)/search"))
    }

    @Test("Returns the body and the HTTP response of a successful request")
    func returnsDataAndResponse() async throws {
        StubURLProtocol.register(.respond(statusCode: 200, data: Data("hello".utf8)), forHost: "success.test")

        let result = try await makeClient().get(try url(host: "success.test"))

        #expect(result.data == Data("hello".utf8))
        #expect(result.response.statusCode == 200)
    }

    @Test("Hands back non-2xx responses untouched; judging the status is the data source's job")
    func doesNotJudgeStatusCodes() async throws {
        StubURLProtocol.register(.respond(statusCode: 503, data: Data()), forHost: "status.test")

        let result = try await makeClient().get(try url(host: "status.test"))

        #expect(result.response.statusCode == 503)
    }

    @Test("A response that is not HTTP is rejected as a bad server response")
    func rejectsNonHTTPResponse() async throws {
        StubURLProtocol.register(.respondNotHTTP(data: Data()), forHost: "nothttp.test")
        let target = try url(host: "nothttp.test")

        do {
            _ = try await makeClient().get(target)
            Issue.record("Expected the request to throw")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        }
    }

    @Test("Transport failures reach the caller as URLError")
    func propagatesTransportFailures() async throws {
        StubURLProtocol.register(.fail(.notConnectedToInternet), forHost: "offline.test")
        let target = try url(host: "offline.test")

        do {
            _ = try await makeClient().get(target)
            Issue.record("Expected the request to throw")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        }
    }

    // MARK: - Cancellation reaches the network layer

    @Test("Cancelling the task aborts the request in flight, and the error maps to CancellationError")
    func cancellationAbortsTheRequest() async throws {
        StubURLProtocol.register(.hang, forHost: "hang.test")
        let client = makeClient()
        let target = try url(host: "hang.test")

        let task = Task { try await client.get(target) }
        #expect(await waitUntil { StubURLProtocol.events(forHost: "hang.test").started == 1 })

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected the cancelled request to throw")
        } catch {
            #expect(DataErrorMapper.map(error) is CancellationError)
        }
        #expect(await waitUntil { StubURLProtocol.events(forHost: "hang.test").stopped == 1 })
    }

    @Test("Full stack: cancelling a search aborts the real request and caches nothing")
    func cancellingASearchAbortsTheRealRequest() async throws {
        let host = "itunes.apple.com"
        StubURLProtocol.register(.hang, forHost: host)
        let cache = SongMemoryCache(clock: ManualCacheClock())
        let repository = CachedSongRepository(
            base: RemoteSongRepository(
                dataSource: ITunesSongRemoteDataSource(httpClient: makeClient())
            ),
            cache: cache
        )
        let query = try #require(SearchQuery("queen"))

        let task = Task { try await repository.searchSongs(matching: query) }
        #expect(await waitUntil { StubURLProtocol.events(forHost: host).started == 1 })

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await waitUntil { StubURLProtocol.events(forHost: host).stopped == 1 })
        #expect(await cache.cachedSongs(for: query) == nil)
    }
}
