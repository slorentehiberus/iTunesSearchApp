import Foundation

/// Top-level payload of `https://itunes.apple.com/search`.
struct ITunesSearchResponseDTO: Decodable, Sendable {
    let resultCount: Int
    let results: [ITunesTrackDTO]
}

extension ITunesSearchResponseDTO {
    /// Decodes a raw iTunes response. A new decoder is created per call
    /// because `JSONDecoder` is not `Sendable`.
    static func decode(from data: Data) throws -> ITunesSearchResponseDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ITunesSearchResponseDTO.self, from: data)
    }
}
