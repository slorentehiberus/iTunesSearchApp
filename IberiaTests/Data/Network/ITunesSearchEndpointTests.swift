import Foundation
import Testing
@testable import Iberia

@Suite("ITunesSearchEndpoint")
struct ITunesSearchEndpointTests {

    @Test("Builds the expected URL and encodes spaces")
    func buildsExpectedURL() throws {
        let url = try ITunesSearchEndpoint.url(for: SearchQuery("Bohemian  Rhapsody")!)

        #expect(url.absoluteString == "https://itunes.apple.com/search?term=bohemian%20rhapsody&entity=song&limit=25")
    }

    @Test("Percent-encodes diacritics as UTF-8")
    func encodesDiacritics() throws {
        let url = try ITunesSearchEndpoint.url(for: SearchQuery("café")!)

        #expect(url.absoluteString.contains("term=caf%C3%A9"))
    }

    @Test("Special characters survive a round trip and cannot inject parameters", arguments: [
        "c++", "rock & roll", "a=b", "100%", "what?", "#1 hit", "mötley crüe"
    ])
    func specialCharactersRoundTrip(raw: String) throws {
        let query = try #require(SearchQuery(raw))

        let url = try ITunesSearchEndpoint.url(for: query)

        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.map(\.name) == ["term", "entity", "limit"])
        #expect(items.first { $0.name == "term" }?.value == query.text)
        #expect(items.first { $0.name == "entity" }?.value == "song")
        #expect(items.first { $0.name == "limit" }?.value == "25")
    }

    @Test("A literal plus sign is escaped so the server does not read it as a space")
    func escapesPlus() throws {
        let url = try ITunesSearchEndpoint.url(for: SearchQuery("c++")!)

        #expect(url.absoluteString.contains("term=c%2B%2B"))
    }
}
