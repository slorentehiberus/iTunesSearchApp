import Foundation

/// Maps iTunes DTOs to Domain entities.
enum ITunesSongMapper {
    /// Maps every valid track, dropping the ones that miss mandatory data. Order is preserved.
    static func songs(from response: ITunesSearchResponseDTO) -> [Song] {
        response.results.compactMap(song(from:))
    }

    /// Returns `nil` when `trackId`, `trackName` or `artistName` is missing.
    static func song(from track: ITunesTrackDTO) -> Song? {
        guard let id = track.trackId,
              let title = track.trackName,
              let artist = track.artistName
        else { return nil }

        let price = decimalPrice(from: track.trackPrice)

        return Song(
            id: id,
            title: title,
            artist: artist,
            album: track.collectionName,
            genre: track.primaryGenreName,
            releaseDate: track.releaseDate,
            artworkURL: track.artworkUrl100.flatMap(URL.init(string:)),
            price: price,
            // The code is only meaningful together with a price.
            currencyCode: price == nil ? nil : track.currency,
            previewURL: track.previewUrl.flatMap(URL.init(string:)),
            durationMilliseconds: track.trackTimeMillis
        )
    }

    /// iTunes reports unavailable prices as a negative number (e.g. -1).
    /// The value goes through its shortest string form so `1.29` stays exactly `1.29`
    /// instead of picking up binary floating-point noise.
    private static func decimalPrice(from value: Double?) -> Decimal? {
        guard let value, value >= 0 else { return nil }
        return Decimal(string: String(value))
    }
}
