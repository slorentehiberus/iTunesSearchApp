import Foundation

/// Every VoiceOver text for songs, in one pure and testable place.
enum SongAccessibility {
    /// Spoken for a list row: one element that reads title and artist.
    static func rowLabel(for song: Song) -> String {
        String(localized: "\(song.title), by \(song.artist)")
    }

    static var rowHint: String {
        String(localized: "Double tap to view song details")
    }

    static func artworkLabel(for song: Song) -> String {
        String(localized: "Album artwork for \(song.title)")
    }

    static var retryHint: String {
        String(localized: "Searches again with the same text")
    }
}
