import Foundation

/// A song returned by a search. Immutable and `Sendable`:
/// it travels between the Data actors and the Presentation `@MainActor` without data races.
/// Optional fields mirror what the iTunes Search API can provide.
public struct Song: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let artist: String
    public let album: String?
    public let genre: String?
    public let releaseDate: Date?
    public let artworkURL: URL?
    public let price: Decimal?
    /// ISO 4217 code (e.g. "USD") that gives `price` its meaning; `nil` whenever `price` is `nil`.
    public let currencyCode: String?
    public let durationMilliseconds: Int?

    public init(
        id: Int,
        title: String,
        artist: String,
        album: String? = nil,
        genre: String? = nil,
        releaseDate: Date? = nil,
        artworkURL: URL? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.releaseDate = releaseDate
        self.artworkURL = artworkURL
        self.price = price
        self.currencyCode = currencyCode
        self.durationMilliseconds = durationMilliseconds
    }
}
