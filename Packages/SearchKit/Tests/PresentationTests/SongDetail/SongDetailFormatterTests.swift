import Foundation
import Testing
@testable import Domain
@testable import Presentation
@testable import TestSupport

@Suite("SongDetailFormatter")
struct SongDetailFormatterTests {
    private let sut = SongDetailFormatter(locale: Locale(identifier: "en_US"))

    @Test("Formats the price with its currency")
    func formatsPriceWithCurrency() {
        let song = Song(id: 1, title: "T", artist: "A", price: Decimal(string: "1.29"), currencyCode: "USD")

        #expect(sut.price(of: song) == "$1.29")
    }

    @Test("A zero price is shown as Free")
    func zeroPriceIsFree() {
        let song = Song(id: 1, title: "T", artist: "A", price: 0, currencyCode: "USD")

        #expect(sut.price(of: song) == "Free")
    }

    @Test("A missing price is shown as Not available")
    func missingPriceIsNotAvailable() {
        #expect(sut.price(of: Song.fixture(id: 1)) == "Not available")
    }

    @Test("Formats the release date in UTC regardless of the device time zone")
    func formatsReleaseDate() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "1975-10-31T12:00:00Z"))
        let song = Song(id: 1, title: "T", artist: "A", releaseDate: date)

        #expect(sut.releaseDate(of: song) == "October 31, 1975")
    }

    @Test("Missing optional fields fall back to readable text")
    func fallbacks() {
        let song = Song.fixture(id: 1)

        #expect(sut.album(of: song) == "Unknown album")
        #expect(sut.genre(of: song) == "Unknown genre")
        #expect(sut.releaseDate(of: song) == "Unknown")
        #expect(sut.duration(of: song) == nil)
    }

    @Test("Formats the duration as minutes and seconds")
    func formatsDuration() {
        let song = Song(id: 1, title: "T", artist: "A", durationMilliseconds: 355_145)

        #expect(sut.duration(of: song) == "5:55")
    }
}
