import Domain
import Foundation

/// Translates transport, HTTP and decoding failures into Domain errors.
enum DataErrorMapper {
    private static let connectivityCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
        .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff
    ]

    static func map(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError, is SearchError:
            return error
        case let urlError as URLError:
            if urlError.code == .cancelled { return CancellationError() }
            if connectivityCodes.contains(urlError.code) { return SearchError.networkUnavailable }
            if urlError.code == .badServerResponse || urlError.code == .cannotParseResponse {
                return SearchError.invalidResponse
            }
            return SearchError.unknown(String(describing: urlError))
        case is DecodingError:
            return SearchError.invalidResponse
        default:
            return SearchError.unknown(String(describing: error))
        }
    }
}
