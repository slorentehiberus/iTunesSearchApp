import Foundation

extension SearchViewState {
    /// Text VoiceOver should announce when the screen changes to this state, or `nil` for silence.
    /// Sighted users see the list, spinner or message appear; VoiceOver users need to be told.
    var announcement: String? {
        switch self {
        case .idle:
            nil
        case .loading:
            String(localized: "Search in progress")
        case .loaded(let songs):
            songs.count == 1
                ? String(localized: "1 song found")
                : String(localized: "\(songs.count) songs found")
        case .empty:
            String(localized: "No songs found")
        case .error(let message):
            message
        }
    }
}
