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

    @Test("Equivalent queries are equal and share the same cache key")
    func equivalentQueriesAreEqual() {
        #expect(SearchQuery("Queen") == SearchQuery("  queen "))
        #expect(SearchQuery("Queen")?.hashValue == SearchQuery(" QUEEN")?.hashValue)
    }

    @Test("Does not fold diacritics: 'cafe' and 'café' are different")
    func doesNotFoldDiacritics() {
        #expect(SearchQuery("cafe") != SearchQuery("café"))
    }
}
