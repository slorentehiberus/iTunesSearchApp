import Testing
@testable import Domain
@testable import Presentation
@testable import TestSupport

/// VoiceOver focus stays in the search field while results change, so the outcome of each search is announced.
@MainActor
@Suite("Search announcements", .timeLimit(.minutes(1)))
struct SearchAnnouncementTests {
    private let songs = [Song.fixture(id: 1), Song.fixture(id: 2)]

    private struct Harness {
        let sut: SearchViewModel
        let spy: SearchSongsUseCaseSpy
        let clock: ManualClock
        let announcer: RecordingAnnouncer
    }

    private func makeHarness(_ behavior: SearchSongsUseCaseSpy.Behavior) -> Harness {
        let spy = SearchSongsUseCaseSpy(behavior: behavior)
        let clock = ManualClock()
        let announcer = RecordingAnnouncer()
        let sut = SearchViewModel(searchSongs: spy, clock: clock, announcer: announcer)
        return Harness(sut: sut, spy: spy, clock: clock, announcer: announcer)
    }

    /// Types `text`, lets the debounce elapse and waits until the request has started.
    private func search(_ text: String, in h: Harness, callCount: Int = 1) async {
        h.sut.searchText = text
        #expect(await waitUntil { h.clock.sleeperCount == 1 })
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { await h.spy.callCount == callCount })
    }

    @Test("Results are announced with their count")
    func announcesResultCount() async {
        let h = makeHarness(.script([.success(songs)]))

        await search("queen", in: h)

        #expect(await waitUntil { h.sut.state == .loaded(songs) })
        #expect(h.announcer.messages == ["2 songs found"])
    }

    @Test("A single result uses the singular form")
    func announcesSingularResult() async {
        let h = makeHarness(.script([.success([Song.fixture(id: 1)])]))

        await search("queen", in: h)

        #expect(await waitUntil { h.sut.state == .loaded([Song.fixture(id: 1)]) })
        #expect(h.announcer.messages == ["1 song found"])
    }

    @Test("An empty result is announced")
    func announcesNoResults() async {
        let h = makeHarness(.script([.success([])]))

        await search("zzzz", in: h)

        #expect(await waitUntil { h.sut.state == .empty })
        #expect(h.announcer.messages == ["No songs found"])
    }

    @Test("A failure announces the same message the screen shows")
    func announcesTheErrorMessage() async {
        let h = makeHarness(.script([.failure(SearchError.serverError)]))

        await search("queen", in: h)

        let expected = SearchError.serverError.userMessage
        #expect(await waitUntil { h.sut.state == .error(expected) })
        #expect(h.announcer.messages == [expected])
    }

    @Test("A cancelled search announces nothing, not even when it answers late")
    func cancelledSearchIsSilent() async {
        let h = makeHarness(.gatedIgnoringCancellation)
        await search("queen", in: h)

        h.sut.searchText = ""
        await h.spy.release(call: 0, with: songs)
        await settle()

        #expect(h.sut.state == .idle)
        #expect(h.announcer.messages.isEmpty)
    }

    @Test("Only the latest search is announced when an older one answers late")
    func staleResultIsNotAnnounced() async {
        let h = makeHarness(.gatedIgnoringCancellation)
        await search("queen", in: h)
        await search("queens", in: h, callCount: 2)

        await h.spy.release(call: 1, with: [Song.fixture(id: 3)])
        #expect(await waitUntil { h.announcer.messages == ["1 song found"] })
        await h.spy.release(call: 0, with: songs)
        await settle()

        #expect(h.announcer.messages == ["1 song found"])
    }

    @Test("Typing does not announce anything until a search ends")
    func nothingIsAnnouncedWhileTyping() async {
        let h = makeHarness(.script([.success(songs)]))

        h.sut.searchText = "q"
        h.sut.searchText = "qu"
        await settle()

        #expect(h.announcer.messages.isEmpty)
    }
}
