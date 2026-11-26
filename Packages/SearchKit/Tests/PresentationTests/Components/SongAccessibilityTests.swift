import Testing
@testable import Domain
@testable import Presentation
@testable import TestSupport

@Suite("SongAccessibility")
struct SongAccessibilityTests {
    private let song = Song(id: 1, title: "Bohemian Rhapsody", artist: "Queen")

    @Test("A row is announced with title and artist")
    func rowLabelHasTitleAndArtist() {
        #expect(SongAccessibility.rowLabel(for: song) == "Bohemian Rhapsody, by Queen")
    }

    @Test("A row tells VoiceOver users what a double tap does")
    func rowHint() {
        #expect(SongAccessibility.rowHint == "Double tap to view song details")
    }

    @Test("The detail artwork has a descriptive label that names the song")
    func artworkLabel() {
        #expect(SongAccessibility.artworkLabel(for: song) == "Album artwork for Bohemian Rhapsody")
    }

    @Test("The retry button explains its effect")
    func retryHint() {
        #expect(!SongAccessibility.retryHint.isEmpty)
    }

    @Test("Labels never come out empty, even for odd data")
    func labelsAreNeverEmpty() {
        let odd = Song(id: 2, title: "?", artist: "…")

        #expect(!SongAccessibility.rowLabel(for: odd).isEmpty)
        #expect(!SongAccessibility.artworkLabel(for: odd).isEmpty)
    }

    @Test("The result count is spoken in singular and plural")
    func resultsAnnouncement() {
        #expect(SongAccessibility.resultsAnnouncement(count: 1) == "1 song found")
        #expect(SongAccessibility.resultsAnnouncement(count: 25) == "25 songs found")
    }

    @Test("An empty search has its own announcement")
    func noResultsAnnouncement() {
        #expect(SongAccessibility.noResultsAnnouncement == "No songs found")
    }
}
