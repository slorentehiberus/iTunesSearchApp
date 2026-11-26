import SwiftUI

extension View {
    /// Keeps content at a comfortable reading width, centered, on wide screens such as an iPad.
    /// On a phone the screen is already narrower than the limit, so it has no effect.
    ///
    /// The limit grows with the text size, so larger Dynamic Type never gets squeezed into a narrow column.
    func readableContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }
}

private struct ReadableContentWidth: ViewModifier {
    @ScaledMetric private var maxWidth: CGFloat

    init(maxWidth: CGFloat) {
        _maxWidth = ScaledMetric(wrappedValue: maxWidth, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
