import Testing
@testable import Iberia

@Suite("SearchViewState VoiceOver announcements")
struct SearchViewStateAnnouncementTests {

    @Test("Idle is silent")
    func idleIsSilent() {
        #expect(SearchViewState.idle.announcement == nil)
    }

    @Test("Loading announces that a search is running")
    func loading() {
        #expect(SearchViewState.loading.announcement == "Search in progress")
    }

    @Test("Results announce how many songs were found, singular and plural")
    func loadedAnnouncesCount() {
        #expect(SearchViewState.loaded([.fixture(id: 1)]).announcement == "1 song found")
        #expect(SearchViewState.loaded([.fixture(id: 1), .fixture(id: 2)]).announcement == "2 songs found")
    }

    @Test("No results are announced")
    func empty() {
        #expect(SearchViewState.empty.announcement == "No songs found")
    }

    @Test("Errors announce their user-facing message")
    func errorAnnouncesMessage() {
        let message = SearchError.networkUnavailable.userMessage

        #expect(SearchViewState.error(message).announcement == message)
    }
}
