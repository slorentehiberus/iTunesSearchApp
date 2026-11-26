import Domain
import Foundation

/// iTunes Search API data source: builds the URL, calls the HTTP client, validates the status code,
/// decodes the JSON and maps it to Domain entities. Every failure leaves as `CancellationError` or `SearchError`.
public struct ITunesSongRemoteDataSource: SongRemoteDataSource {
    private let httpClient: any HTTPClientProtocol

    public init(httpClient: any HTTPClientProtocol) {
        self.httpClient = httpClient
    }

    public func fetchSongs(for query: SearchQuery) async throws -> [Song] {
        do {
            try Task.checkCancellation()
            let url = try ITunesSearchEndpoint.url(for: query)
            let (data, response) = try await httpClient.get(url)
            // A cancelled request must not produce a result.
            try Task.checkCancellation()

            guard (200..<300).contains(response.statusCode) else {
                throw SearchError.serverError
            }
            let dto = try ITunesSearchResponseDTO.decode(from: data)
            return ITunesSongMapper.songs(from: dto)
        } catch {
            throw DataErrorMapper.map(error)
        }
    }
}
