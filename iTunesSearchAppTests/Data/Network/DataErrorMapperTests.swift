import Foundation
import Testing
@testable import iTunesSearchApp

@Suite("DataErrorMapper")
struct DataErrorMapperTests {

    @Test("URLError(.cancelled) maps to CancellationError")
    func cancelledMapsToCancellation() {
        #expect(DataErrorMapper.map(URLError(.cancelled)) is CancellationError)
    }

    @Test("Connectivity URLErrors map to networkUnavailable", arguments: [
        URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed
    ])
    func connectivityMapsToNetworkUnavailable(code: URLError.Code) {
        #expect(DataErrorMapper.map(URLError(code)) as? SearchError == .networkUnavailable)
    }

    @Test("Bad server responses map to invalidResponse", arguments: [
        URLError.Code.badServerResponse, .cannotParseResponse
    ])
    func badResponseMapsToInvalidResponse(code: URLError.Code) {
        #expect(DataErrorMapper.map(URLError(code)) as? SearchError == .invalidResponse)
    }

    @Test("Other URLErrors keep their description in SearchError.unknown")
    func otherURLErrorsMapToUnknown() throws {
        let mapped = try #require(DataErrorMapper.map(URLError(.badURL)) as? SearchError)

        guard case .unknown(let description) = mapped else {
            Issue.record("Expected .unknown, got \(mapped)")
            return
        }
        #expect(!description.isEmpty)
    }

    @Test("DecodingError maps to invalidResponse")
    func decodingErrorMapsToInvalidResponse() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))

        #expect(DataErrorMapper.map(error) as? SearchError == .invalidResponse)
    }

    @Test("Domain errors and cancellation pass through untouched")
    func passesThroughDomainErrors() {
        #expect(DataErrorMapper.map(SearchError.serverError) as? SearchError == .serverError)
        #expect(DataErrorMapper.map(CancellationError()) is CancellationError)
    }
}
