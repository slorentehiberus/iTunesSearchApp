import SwiftUI

/// Hosts a full-screen state (welcome, error…). If the content fits it stays centered;
/// if it does not (huge Dynamic Type, small screens) it becomes scrollable instead of being cut off.
struct ScrollableStateView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
        }
    }
}
