import SwiftUI

/// Square album artwork. Shows a placeholder while loading, when loading fails and when there is no URL.
/// Accessibility is left to the caller: decorative in lists, labelled in the detail screen.
struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
