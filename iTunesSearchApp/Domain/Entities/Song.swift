import Foundation

/// A song returned by a search. Immutable and `Sendable`:
/// it travels between the Data actors and the Presentation `@MainActor` without data races.
/// Optional fields mirror what the iTunes Search API can provide.
struct Song: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let artist: String
    let album: String?
    let genre: String?
    let releaseDate: Date?
    let artworkURL: URL?
    let price: Decimal?
    /// ISO 4217 code (e.g. "USD") that gives `price` its meaning; `nil` whenever `price` is `nil`.
    let currencyCode: String?
    let previewURL: URL?
    let durationMilliseconds: Int?

    init(
        id: Int,
        title: String,
        artist: String,
        album: String? = nil,
        genre: String? = nil,
        releaseDate: Date? = nil,
        artworkURL: URL? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil,
        previewURL: URL? = nil,
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
        self.previewURL = previewURL
        self.durationMilliseconds = durationMilliseconds
    }
}
