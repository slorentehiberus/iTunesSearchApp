import Testing
@testable import Domain

@Suite("SearchQuery")
struct SearchQueryTests {

    @Test("Rejects empty or whitespace-only text", arguments: ["", " ", "\t\n  "])
    func rejectsBlankText(raw: String) {
        #expect(SearchQuery(raw) == nil)
    }

    @Test("Normalizes: trim, lowercase and collapsed inner whitespace")
    func normalizesText() {
        #expect(SearchQuery("  Hello   WORLD \n")?.text == "hello world")
    }

    @Test("Does not fold diacritics: 'cafe' and 'café' are different")
    func doesNotFoldDiacritics() {
        #expect(SearchQuery("cafe") != SearchQuery("café"))
    }
}
