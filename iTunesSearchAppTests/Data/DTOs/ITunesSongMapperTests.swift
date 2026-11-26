import Foundation
import Testing
@testable import Data
@testable import Domain

@Suite("iTunes DTO decoding and mapping")
struct ITunesSongMapperTests {

    private func songs(from data: Data) throws -> [Song] {
        ITunesSongMapper.songs(from: try ITunesSearchResponseDTO.decode(from: data))
    }

    @Test("Parses a real iTunes response, including price and currency")
    func parsesRealResponse() throws {
        let result = try songs(from: ITunesFixtures.realSample)

        #expect(result.map(\.id) == [6781080934, 6781080941])
        let first = try #require(result.first)
        #expect(first.title == "Bohemian Rhapsody")
        #expect(first.artist == "Queen")
        #expect(first.album == "The Platinum Collection")
        #expect(first.genre == "Rock")
        #expect(first.price == Decimal(string: "1.29"))
        #expect(first.currencyCode == "USD")
        #expect(first.durationMilliseconds == 355145)
        #expect(first.artworkURL?.absoluteString.hasSuffix("100x100bb.jpg") == true)
        #expect(first.previewURL?.host() == "audio-ssl.itunes.apple.com")
        #expect(first.releaseDate == ISO8601DateFormatter().date(from: "1975-10-31T12:00:00Z"))
    }

    @Test("Optional fields missing in the payload map to nil")
    func missingOptionalFieldsAreNil() throws {
        let result = try songs(from: ITunesFixtures.realSample)

        let second = try #require(result.last)
        #expect(second.previewURL == nil)
        #expect(second.price == Decimal(string: "1.29"))
    }

    @Test("Items missing id, title or artist are dropped; the rest keep their order")
    func dropsIncompleteItems() throws {
        let result = try songs(from: ITunesFixtures.partialItems)

        #expect(result.map(\.id) == [1])
    }

    @Test("A negative (unavailable) price maps to nil price and nil currency")
    func unavailablePriceMapsToNil() throws {
        let song = try #require(try songs(from: ITunesFixtures.unavailablePrice).first)

        #expect(song.price == nil)
        #expect(song.currencyCode == nil)
    }

    @Test("Price keeps exact decimal digits")
    func priceIsExact() {
        let track = ITunesTrackDTO(
            trackId: 1, trackName: "T", artistName: "A", collectionName: nil,
            primaryGenreName: nil, releaseDate: nil, artworkUrl100: nil, previewUrl: nil,
            trackPrice: 0.99, currency: "EUR", trackTimeMillis: nil
        )

        #expect(ITunesSongMapper.song(from: track)?.price == Decimal(string: "0.99"))
    }

    @Test("Malformed JSON throws a decoding error")
    func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            try ITunesSearchResponseDTO.decode(from: ITunesFixtures.notJSON)
        }
    }
}
