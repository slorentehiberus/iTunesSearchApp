import SwiftUI

extension ShapeStyle where Self == Color {
    /// Secondary text color that still meets the contrast ratio the accessibility audit requires.
    /// SwiftUI's `.secondary` is too light for small text on a white background.
    static var mutedText: Color {
        Color.primary.opacity(0.75)
    }
}
