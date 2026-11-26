import Foundation

extension SearchError {
    /// Message shown to the user. Domain errors never reach the UI as raw values.
    var userMessage: String {
        switch self {
        case .networkUnavailable:
            String(localized: "You seem to be offline. Check your connection and try again.")
        case .serverError:
            String(localized: "The music service is having problems. Please try again later.")
        case .invalidResponse:
            String(localized: "We received an unexpected response. Please try again.")
        case .unknown:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}
