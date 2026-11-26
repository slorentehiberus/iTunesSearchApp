import Domain
import Foundation

/// One element of `results`, limited to the fields the app uses.
///
/// Every field is optional so a single incomplete item never makes the whole response
/// fail to decode; the mapper drops items that lack the mandatory data.
struct ITunesTrackDTO: Decodable, Sendable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let primaryGenreName: String?
    let releaseDate: Date?
    let artworkUrl100: String?
    let trackPrice: Double?
    let currency: String?
    let trackTimeMillis: Int?
}
