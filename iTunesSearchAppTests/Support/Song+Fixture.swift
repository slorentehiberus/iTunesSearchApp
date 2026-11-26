@testable import iTunesSearchApp

extension Song {
    static func fixture(
        id: Int,
        title: String = "Title",
        artist: String = "Artist"
    ) -> Song {
        Song(id: id, title: title, artist: artist)
    }
}
