import Foundation

/// Builds iTunes Search API URLs.
enum ITunesSearchEndpoint {
    static let limit = 25

    /// `https://itunes.apple.com/search?term=<query>&entity=song&limit=25`
    /// The term is percent-encoded by `URLComponents`.
    static func url(for query: SearchQuery) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: query.text),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        // `URLComponents` leaves a literal "+" untouched, but servers decode "+" as a space.
        // Spaces are already "%20", so every remaining "+" is data and must be escaped.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        guard let url = components.url else {
            throw SearchError.unknown("Could not build the search URL")
        }
        return url
    }
}
