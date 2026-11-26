/// Domain errors for a search. Cancellation is NOT a case:
/// it propagates as `CancellationError` and the UI ignores it.
enum SearchError: Error, Equatable, Sendable {
    case networkUnavailable
    case serverError
    case invalidResponse
    /// Any other failure; carries the original error's description for debugging.
    case unknown(String)
}
