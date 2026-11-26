import Testing
@testable import Domain
@testable import Presentation

@Suite("SongAccessibility")
struct SongAccessibilityTests {
    private let song = Song(id: 1, title: "Bohemian Rhapsody", artist: "Queen")

    @Test("A row is announced with title and artist")
    func rowLabelHasTitleAndArtist() {
        #expect(SongAccessibility.rowLabel(for: song) == "Bohemian Rhapsody, by Queen")
    }

    @Test("The detail artwork has a descriptive label that names the song")
    func artworkLabel() {
        #expect(SongAccessibility.artworkLabel(for: song) == "Album artwork for Bohemian Rhapsody")
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
