#if DEBUG
import Domain
import Foundation

/// Offline, deterministic use case for UI tests (`-UITestStubbedSearch` launch argument).
/// Never compiled into release builds.
///
/// - "zzzz" → no results, "error" → a server error, "long" → only the song with very long texts,
///   anything else → three songs.
struct StubbedSearchSongsUseCase: SearchSongsUseCase {
    func execute(query: String) async throws -> [Song] {
        switch SearchQuery(query)?.text {
        case nil:
            return []
        case "zzzz":
            return []
        case "error":
            throw SearchError.serverError
        case "long":
            return Array(Self.songs.suffix(1))
        default:
            return Self.songs
        }
    }

    private static let songs = [
        Song(
            id: 1, title: "Bohemian Rhapsody", artist: "Queen",
            album: "The Platinum Collection", genre: "Rock",
            releaseDate: Date(timeIntervalSince1970: 183_297_600),
            price: Decimal(string: "1.29"), currencyCode: "USD", durationMilliseconds: 355_145
        ),
        Song(id: 2, title: "Don't Stop Me Now", artist: "Queen", album: "Jazz", genre: "Rock"),
        Song(
            id: 3,
            title: "A Very Long Song Title That Must Wrap Across Several Lines At Large Text Sizes",
            artist: "An Artist With An Equally Long Name To Prove Nothing Is Truncated",
            album: "A Long Album Name That Also Needs To Wrap Without Being Cut Off"
        )
    ]
}
#endif
