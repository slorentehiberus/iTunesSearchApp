import Foundation
import Testing
@testable import Iberia

@Suite("Song artwork URL")
struct SongArtworkTests {

    @Test("Requests a larger rendition of an iTunes artwork URL")
    func upscalesITunesArtwork() throws {
        let url = try #require(URL(string: "https://is1-ssl.mzstatic.com/image/thumb/abc/100x100bb.jpg"))
        let song = Song(id: 1, title: "T", artist: "A", artworkURL: url)

        #expect(song.artworkURL(pixelSize: 600)?.absoluteString
                == "https://is1-ssl.mzstatic.com/image/thumb/abc/600x600bb.jpg")
    }

    @Test("Leaves URLs without the size marker untouched")
    func keepsOtherURLs() throws {
        let url = try #require(URL(string: "https://example.com/cover.jpg"))
        let song = Song(id: 1, title: "T", artist: "A", artworkURL: url)

        #expect(song.artworkURL(pixelSize: 600) == url)
    }

    @Test("No artwork means no URL")
    func noArtwork() {
        #expect(Song.fixture(id: 1).artworkURL(pixelSize: 600) == nil)
    }
}
