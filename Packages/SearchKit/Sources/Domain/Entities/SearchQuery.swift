/// Value object representing a valid search.
///
/// Normalization: trims leading/trailing whitespace, collapses inner whitespace
/// and lowercases. Diacritics are NOT folded ("cafe" and "café" are different queries),
/// so the cache never mixes results the server may return differently.
public struct SearchQuery: Hashable, Sendable {
    /// Normalized text. It is the cache key and the term sent to the API.
    public let text: String

    /// Returns `nil` if the text is empty or contains only whitespace.
    public init?(_ rawValue: String) {
        let normalized = rawValue
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        self.text = normalized
    }
}
