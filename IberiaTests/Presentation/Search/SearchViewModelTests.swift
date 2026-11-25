import Testing
@testable import Iberia

@MainActor
@Suite("SearchViewModel", .timeLimit(.minutes(1)))
struct SearchViewModelTests {
    private let songs = [Song.fixture(id: 1), Song.fixture(id: 2)]
    private let otherSongs = [Song.fixture(id: 3)]

    private struct Harness {
        let sut: SearchViewModel
        let spy: SearchSongsUseCaseSpy
        let clock: ManualClock
    }

    private func makeHarness(_ behavior: SearchSongsUseCaseSpy.Behavior) -> Harness {
        let spy = SearchSongsUseCaseSpy(behavior: behavior)
        let clock = ManualClock()
        return Harness(sut: SearchViewModel(searchSongs: spy, clock: clock), spy: spy, clock: clock)
    }

    /// Types `text` and waits until its debounce timer is running.
    private func type(_ text: String, into h: Harness) async {
        h.sut.searchText = text
        #expect(await waitUntil { h.clock.sleeperCount == 1 })
    }

    /// Lets the debounce elapse and waits until the (gated) request has started.
    private func startRequest(in h: Harness, callCount: Int = 1) async {
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { await h.spy.callCount == callCount })
    }

    // MARK: - Debounce and cancellation

    @Test("Rapid typing cancels intermediate searches and calls the use case once with the final text")
    func debounceCollapsesRapidTyping() async {
        let h = makeHarness(.script([.success(songs)]))

        for text in ["q", "qu", "que", "queen"] {
            await type(text, into: h)
        }

        h.clock.advance(by: .milliseconds(299))
        await settle()
        #expect(await h.spy.callCount == 0)
        #expect(h.sut.state == .loading)

        h.clock.advance(by: .milliseconds(1))
        #expect(await waitUntil { h.sut.state == .loaded(songs) })
        #expect(await h.spy.receivedQueries == ["queen"])
    }

    @Test("Clearing the text during the debounce cancels the pending search")
    func clearingDuringDebounceCancels() async {
        let h = makeHarness(.script([.success(songs)]))
        await type("queen", into: h)

        h.sut.searchText = ""

        #expect(h.sut.state == .idle)
        #expect(h.clock.sleeperCount == 0)
        h.clock.advance(by: .milliseconds(300))
        await settle()
        #expect(await h.spy.callCount == 0)
        #expect(h.sut.state == .idle)
    }

    @Test("Clearing the text while a request is in flight cancels it and ignores its result")
    func clearingDuringRequestCancels() async {
        let h = makeHarness(.gated)
        await type("queen", into: h)
        await startRequest(in: h)
        #expect(h.sut.state == .loading)

        h.sut.searchText = ""
        #expect(h.sut.state == .idle)

        #expect(await waitUntil { await h.spy.cancelledCalls.contains(0) })
        await h.spy.release(call: 0, with: songs)
        await settle()
        #expect(h.sut.state == .idle)
    }

    @Test("Whitespace-only text resets to idle without starting a task")
    func whitespaceOnlyTextIsIdle() async {
        let h = makeHarness(.script([.success(songs)]))

        h.sut.searchText = "   "
        await settle()

        #expect(h.sut.state == .idle)
        #expect(h.clock.sleeperCount == 0)
        #expect(await h.spy.callCount == 0)
    }

    @Test("A cancelled request that still returns late never overwrites newer results")
    func staleResultNeverOverwritesNewerOne() async {
        let h = makeHarness(.gatedIgnoringCancellation)
        await type("queen", into: h)
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { await h.spy.callCount == 1 })

        await type("queens", into: h)
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { await h.spy.callCount == 2 })

        await h.spy.release(call: 1, with: otherSongs)
        #expect(await waitUntil { h.sut.state == .loaded(otherSongs) })

        // The first request, already cancelled, answers late with outdated data.
        await h.spy.release(call: 0, with: songs)
        await settle()
        #expect(h.sut.state == .loaded(otherSongs))
    }

    // MARK: - State transitions

    @Test("Goes idle, then loading, then loaded")
    func idleToLoadingToLoaded() async {
        let h = makeHarness(.gated)
        #expect(h.sut.state == .idle)

        await type("queen", into: h)
        #expect(h.sut.state == .loading) // typing already shows loading, even while debouncing

        await startRequest(in: h)
        #expect(h.sut.state == .loading) // request in flight

        await h.spy.release(call: 0, with: songs)
        #expect(await waitUntil { h.sut.state == .loaded(songs) })
    }

    @Test("An empty result becomes the empty state")
    func emptyResult() async {
        let h = makeHarness(.script([.success([])]))
        await type("zzzz", into: h)

        h.clock.advance(by: .milliseconds(300))

        #expect(await waitUntil { h.sut.state == .empty })
    }

    @Test("A failure becomes the error state with a user-facing message and does not crash on cancellation")
    func failureBecomesError() async {
        let h = makeHarness(.script([.failure(SearchError.serverError)]))
        await type("queen", into: h)

        h.clock.advance(by: .milliseconds(300))

        #expect(await waitUntil { h.sut.state == .error(SearchError.serverError.userMessage) })
    }

    @Test("A CancellationError from the use case never produces an error state")
    func cancellationErrorIsIgnored() async {
        let h = makeHarness(.script([.failure(CancellationError())]))
        await type("queen", into: h)

        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { await h.spy.callCount == 1 })
        await settle()

        #expect(!isError(h.sut.state))
    }

    @Test("Retry re-runs the current search immediately, without waiting for the debounce")
    func retryAfterError() async {
        let h = makeHarness(.script([.failure(SearchError.networkUnavailable), .success(songs)]))
        await type("queen", into: h)
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { h.sut.state == .error(SearchError.networkUnavailable.userMessage) })

        h.sut.retry()
        #expect(h.sut.state == .loading)

        #expect(await waitUntil { h.sut.state == .loaded(songs) })
        #expect(await h.spy.receivedQueries == ["queen", "queen"])
        #expect(h.clock.sleeperCount == 0)
    }

    @Test("Retry with blank text stays idle")
    func retryWithBlankTextIsIdle() async {
        let h = makeHarness(.script([.success(songs)]))

        h.sut.retry()
        await settle()

        #expect(h.sut.state == .idle)
        #expect(await h.spy.callCount == 0)
    }

    // MARK: - Results of an earlier search are never shown

    @Test("As soon as the text changes, the previous results leave the screen")
    func previousResultsAreDroppedWhenTextChanges() async {
        let h = makeHarness(.gated)
        await type("queen", into: h)
        await startRequest(in: h)
        await h.spy.release(call: 0, with: songs)
        #expect(await waitUntil { h.sut.state == .loaded(songs) })

        h.sut.searchText = "queens"

        #expect(h.sut.state == .loading)
        #expect(await waitUntil { h.clock.sleeperCount == 1 }) // new debounce is running
        await startRequest(in: h, callCount: 2)
        #expect(h.sut.state == .loading)

        await h.spy.release(call: 1, with: otherSongs)
        #expect(await waitUntil { h.sut.state == .loaded(otherSongs) })
    }

    @Test("A previous empty result does not linger once the text changes")
    func previousEmptyStateIsDropped() async {
        let h = makeHarness(.gated)
        await type("zzzz", into: h)
        await startRequest(in: h)
        await h.spy.release(call: 0, with: [])
        #expect(await waitUntil { h.sut.state == .empty })

        h.sut.searchText = "zzzzz"

        #expect(h.sut.state == .loading)
    }

    @Test("A previous error does not linger once the text changes")
    func previousErrorIsDropped() async {
        let h = makeHarness(.script([.failure(SearchError.serverError), .success(songs)]))
        await type("queen", into: h)
        h.clock.advance(by: .milliseconds(300))
        #expect(await waitUntil { h.sut.state == .error(SearchError.serverError.userMessage) })

        h.sut.searchText = "queens"

        #expect(h.sut.state == .loading)
    }

    @Test("Editing the text repeatedly while loading keeps a single, steady loading state")
    func typingWhileLoadingStaysLoading() async {
        let h = makeHarness(.script([.success(songs)]))

        for text in ["q", "qu", "que", "quee", "queen"] {
            await type(text, into: h)
            #expect(h.sut.state == .loading)
        }
    }

    // MARK: - Submit

    @Test("Submitting searches immediately, skipping the debounce, and only once")
    func submitSearchesImmediately() async {
        let h = makeHarness(.script([.success(songs)]))
        await type("queen", into: h)

        h.sut.submit()
        #expect(h.sut.state == .loading)

        #expect(await waitUntil { h.sut.state == .loaded(songs) })
        h.clock.advance(by: .milliseconds(300))
        await settle()
        #expect(await h.spy.receivedQueries == ["queen"])
    }

    @Test("Submitting blank text stays idle")
    func submitWithBlankTextIsIdle() async {
        let h = makeHarness(.script([.success(songs)]))

        h.sut.submit()
        await settle()

        #expect(h.sut.state == .idle)
        #expect(await h.spy.callCount == 0)
    }

    private func isError(_ state: SearchViewState) -> Bool {
        if case .error = state { return true }
        return false
    }
}
