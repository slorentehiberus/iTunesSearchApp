/// What the search screen shows. Explicit, mutually exclusive states.
enum SearchViewState: Equatable, Sendable {
    /// Nothing typed yet (or the text was cleared).
    case idle
    /// A request is in flight and there are no previous results to keep on screen.
    case loading
    case loaded([Song])
    /// The search succeeded but returned no songs.
    case empty
    /// The search failed; carries a user-facing message.
    case error(String)
}

extension SearchViewState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
