import Foundation

extension Song {
    /// iTunes serves artwork at the size written in the file name (`.../100x100bb.jpg`).
    /// Asks for a larger rendition so the detail screen is not blurry; any other URL is returned unchanged.
    func artworkURL(pixelSize: Int) -> URL? {
        guard let artworkURL else { return nil }
        let original = "100x100bb"
        let absolute = artworkURL.absoluteString
        guard absolute.contains(original) else { return artworkURL }
        let resized = absolute.replacingOccurrences(of: original, with: "\(pixelSize)x\(pixelSize)bb")
        return URL(string: resized) ?? artworkURL
    }
}
