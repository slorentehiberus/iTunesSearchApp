import Domain
import Observation

/// Drives the search screen: search-as-you-type with debounce and strict cancellation.
///
/// - Every text change cancels the previous task immediately.
/// - Blank text resets to `.idle` at once, with no task and no network.
/// - Any other change shows `.loading` at once, so results of an earlier search are never on screen
///   next to a newer text. A new task then waits `debounce` on the injected clock and queries the use case.
/// - A cancelled task never touches the state: stale results can not overwrite newer ones.
@MainActor
@Observable
public final class SearchViewModel {
    static let defaultDebounce: Duration = .milliseconds(300)

    /// Text typed by the user. Writing a different value to it (e.g. through `.searchable`) starts a search.
    var searchText = "" {
        didSet {
            if searchText != oldValue { searchTextDidChange() }
        }
    }

    private(set) var state: SearchViewState = .idle

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private let searchSongs: any SearchSongsUseCase
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let announcer: any AccessibilityAnnouncer

    /// Production initializer: system clock and the default debounce.
    public convenience init(searchSongs: any SearchSongsUseCase) {
        self.init(searchSongs: searchSongs, clock: ContinuousClock(), debounce: Self.defaultDebounce,
                  announcer: SystemAccessibilityAnnouncer())
    }

    /// Lets tests inject a manual clock, a shorter debounce and a recording announcer.
    init(
        searchSongs: any SearchSongsUseCase,
        clock: any Clock<Duration>,
        debounce: Duration = SearchViewModel.defaultDebounce,
        announcer: any AccessibilityAnnouncer = SystemAccessibilityAnnouncer()
    ) {
        self.searchSongs = searchSongs
        self.clock = clock
        self.debounce = debounce
        self.announcer = announcer
    }

    /// Re-runs the current search immediately (no debounce), from the error screen's Retry button.
    func retry() {
        searchImmediately()
    }

    /// Searches right away when the user presses the keyboard's Search key, skipping the debounce.
    func submit() {
        searchImmediately()
    }

    // MARK: - Private

    private func searchImmediately() {
        searchTask?.cancel()
        guard SearchQuery(searchText) != nil else {
            searchTask = nil
            state = .idle
            return
        }
        state = .loading
        startSearch(after: .zero)
    }

    private func searchTextDidChange() {
        searchTask?.cancel()
        guard SearchQuery(searchText) != nil else {
            searchTask = nil
            state = .idle
            return
        }
        // Whatever is on screen (results, empty or error) belongs to an older text: drop it now.
        state = .loading
        startSearch(after: debounce)
    }

    private func startSearch(after delay: Duration) {
        let text = searchText
        searchTask = Task { [weak self] in
            await self?.runSearch(for: text, after: delay)
        }
    }

    private func runSearch(for text: String, after delay: Duration) async {
        do {
            if delay > .zero {
                try await clock.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }

            let songs = try await searchSongs.execute(query: text)
            guard !Task.isCancelled else { return }

            if songs.isEmpty {
                state = .empty
                announcer.announce(SongAccessibility.noResultsAnnouncement)
            } else {
                state = .loaded(songs)
                announcer.announce(SongAccessibility.resultsAnnouncement(count: songs.count))
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            let searchError = (error as? SearchError) ?? .unknown(String(describing: error))
            state = .error(searchError.userMessage)
            announcer.announce(searchError.userMessage)
        }
    }
}
