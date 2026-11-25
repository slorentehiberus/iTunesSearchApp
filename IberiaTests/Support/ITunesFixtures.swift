import Foundation

/// JSON payloads for Data tests.
enum ITunesFixtures {
    /// Two tracks copied from a real `search?term=queen&entity=song&limit=2` response.
    static let realSample = Data(#"""
    {
      "resultCount": 2,
      "results": [
        {
          "wrapperType": "track", "kind": "song", "artistId": 3296287, "collectionId": 6781080933,
          "trackId": 6781080934, "artistName": "Queen", "collectionName": "The Platinum Collection",
          "trackName": "Bohemian Rhapsody", "collectionCensoredName": "The Platinum Collection",
          "trackCensoredName": "Bohemian Rhapsody",
          "artistViewUrl": "https://music.apple.com/us/artist/queen/3296287?uo=4",
          "collectionViewUrl": "https://music.apple.com/us/album/bohemian-rhapsody/6781080933?i=6781080934&uo=4",
          "trackViewUrl": "https://music.apple.com/us/album/bohemian-rhapsody/6781080933?i=6781080934&uo=4",
          "previewUrl": "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/bb/b7/14/bbb714e5-8d2f-dc88-8773-67b19d71178b/mzaf_6782698911866218823.plus.aac.p.m4a",
          "artworkUrl30": "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/15/c7/55/15c755bc-7603-3ce3-e243-e59f1f9863ea/602527724171.jpg/30x30bb.jpg",
          "artworkUrl60": "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/15/c7/55/15c755bc-7603-3ce3-e243-e59f1f9863ea/602527724171.jpg/60x60bb.jpg",
          "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/15/c7/55/15c755bc-7603-3ce3-e243-e59f1f9863ea/602527724171.jpg/100x100bb.jpg",
          "collectionPrice": 39.99, "trackPrice": 1.29, "releaseDate": "1975-10-31T12:00:00Z",
          "collectionExplicitness": "notExplicit", "trackExplicitness": "notExplicit",
          "discCount": 3, "discNumber": 1, "trackCount": 17, "trackNumber": 1,
          "trackTimeMillis": 355145, "country": "USA", "currency": "USD",
          "primaryGenreName": "Rock", "isStreamable": true
        },
        {
          "wrapperType": "track", "kind": "song", "artistId": 3296287, "collectionId": 6781080933,
          "trackId": 6781080941, "artistName": "Queen", "collectionName": "The Platinum Collection",
          "trackName": "Don't Stop Me Now",
          "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/15/c7/55/15c755bc-7603-3ce3-e243-e59f1f9863ea/602527724171.jpg/100x100bb.jpg",
          "collectionPrice": 39.99, "trackPrice": 1.29, "releaseDate": "1978-11-10T12:00:00Z",
          "trackTimeMillis": 210333, "country": "USA", "currency": "USD",
          "primaryGenreName": "Rock", "isStreamable": true
        }
      ]
    }
    """#.utf8)

    /// Builds a minimal valid response with the given track ids.
    static func response(trackIDs: [Int], artist: String = "Artist") -> Data {
        let tracks = trackIDs.map {
            #"{"trackId": \#($0), "trackName": "Song \#($0)", "artistName": "\#(artist)"}"#
        }
        let json = #"{"resultCount": \#(trackIDs.count), "results": [\#(tracks.joined(separator: ","))]}"#
        return Data(json.utf8)
    }

    /// One complete track, one without `trackName`, one without `artistName` and one with no id.
    static let partialItems = Data(#"""
    {
      "resultCount": 4,
      "results": [
        {"trackId": 1, "trackName": "Valid", "artistName": "Artist"},
        {"trackId": 2, "artistName": "Artist"},
        {"trackId": 3, "trackName": "No artist"},
        {"trackName": "No id", "artistName": "Artist"}
      ]
    }
    """#.utf8)

    /// iTunes reports unavailable prices as -1.
    static let unavailablePrice = Data(#"""
    {"resultCount": 1, "results": [
      {"trackId": 1, "trackName": "T", "artistName": "A", "trackPrice": -1, "currency": "USD"}
    ]}
    """#.utf8)

    static let notJSON = Data("<html>not json</html>".utf8)
}
