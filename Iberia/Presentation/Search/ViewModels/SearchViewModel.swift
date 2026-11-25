import Observation

/// Drives the search screen: search-as-you-type with debounce and strict cancellation.
///
/// - Every text change cancels the previous task immediately.
/// - Blank text resets to `.idle` at once, with no task and no network.
/// - Otherwise a new task waits `debounce` on the injected clock and then queries the use case.
/// - A cancelled task never touches the state: stale results can not overwrite newer ones.
@MainActor
@Observable
final class SearchViewModel {
    static let defaultDebounce: Duration = .milliseconds(300)
    /// How long a request may take before the spinner appears. Faster answers never flash it.
    static let defaultLoadingDelay: Duration = .milliseconds(150)

    /// Text typed by the user. Writing to it (e.g. through `.searchable`) triggers the search.
    /// Implemented by hand so the write can start the search while staying observable.
    var searchText: String {
        get {
            access(keyPath: \.searchText)
            return storedSearchText
        }
        set {
            guard newValue != storedSearchText else { return }
            withMutation(keyPath: \.searchText) { storedSearchText = newValue }
            searchTextDidChange()
        }
    }

    private(set) var state: ViewState = .idle

    typealias ViewState = SearchViewState

    @ObservationIgnored private var storedSearchText = ""
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private let searchSongs: any SearchSongsUseCase
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let loadingDelay: Duration

    init(
        searchSongs: any SearchSongsUseCase,
        clock: any Clock<Duration> = ContinuousClock(),
        debounce: Duration = SearchViewModel.defaultDebounce,
        loadingDelay: Duration = SearchViewModel.defaultLoadingDelay
    ) {
        self.searchSongs = searchSongs
        self.clock = clock
        self.debounce = debounce
        self.loadingDelay = loadingDelay
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
        startSearch(after: .zero)
    }

    private func searchTextDidChange() {
        searchTask?.cancel()
        guard SearchQuery(searchText) != nil else {
            searchTask = nil
            state = .idle
            return
        }
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

            // The spinner appears only if the request is slow, so cached or fast answers never flash it.
            let loadingTimer = scheduleLoadingIndicator()
            defer { loadingTimer.cancel() }

            let songs = try await withTaskCancellationHandler {
                try await searchSongs.execute(query: text)
            } onCancel: {
                // A cancelled search must not leave a spinner timer behind, even if the use case answers late.
                loadingTimer.cancel()
            }
            guard !Task.isCancelled else { return }

            state = songs.isEmpty ? .empty : .loaded(songs)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            let searchError = (error as? SearchError) ?? .unknown(String(describing: error))
            state = .error(searchError.userMessage)
        }
    }

    private func scheduleLoadingIndicator() -> Task<Void, Never> {
        let clock = clock
        let delay = loadingDelay
        return Task { [weak self] in
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.beginLoading()
        }
    }

    /// Shows the spinner only when there is nothing useful on screen. If results are already
    /// displayed they stay until the new ones arrive, which avoids a list → spinner → list flash.
    private func beginLoading() {
        if case .loaded = state { return }
        state = .loading
    }
}
