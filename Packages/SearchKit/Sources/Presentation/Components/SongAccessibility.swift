import Domain
import Foundation

/// Every VoiceOver text for songs, in one pure and testable place.
enum SongAccessibility {
    /// Spoken for a list row: one element that reads title and artist.
    static func rowLabel(for song: Song) -> String {
        String(localized: "\(song.title), by \(song.artist)", bundle: .module)
    }

    static var rowHint: String {
        String(localized: "Double tap to view song details", bundle: .module)
    }

    static func artworkLabel(for song: Song) -> String {
        String(localized: "Album artwork for \(song.title)", bundle: .module)
    }

    static var retryHint: String {
        String(localized: "Searches again with the same text", bundle: .module)
    }

    /// Spoken when a search ends with results: VoiceOver focus stays in the search field, so the outcome
    /// would otherwise go unnoticed.
    static func resultsAnnouncement(count: Int) -> String {
        count == 1
            ? String(localized: "1 song found", bundle: .module)
            : String(localized: "\(count) songs found", bundle: .module)
    }

    static var noResultsAnnouncement: String {
        String(localized: "No songs found", bundle: .module)
    }
}
