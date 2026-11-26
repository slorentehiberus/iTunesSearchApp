import SwiftUI
import Foundation

/// Song detail. Artwork above the metadata on narrow screens; side by side on wide or landscape ones.
/// Everything lives in a `ScrollView` so nothing is cut off on small devices or large text sizes.
struct SongDetailView: View {
    let song: Song

    private let formatter = SongDetailFormatter()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Wide (iPad, large iPhone landscape) or short (iPhone landscape) screens, unless text is huge.
    private var usesSideBySideLayout: Bool {
        (horizontalSizeClass == .regular || verticalSizeClass == .compact)
            && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            let layout = usesSideBySideLayout
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))

            layout {
                artwork
                details
            }
            .padding()
            .readableContentWidth(900)
        }
        // A short fixed title: the song's own title is the heading in the body, where it wraps freely.
        // As a navigation title it would be cut off with "…" at large text sizes.
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("songDetail")
    }

    /// Widest the cover may be. An iPhone in landscape is short (about 400 pt), so a smaller cover
    /// fits without scrolling; an iPad has the room for a bigger one.
    private var artworkMaxWidth: CGFloat {
        guard usesSideBySideLayout else { return 420 }
        return verticalSizeClass == .compact ? 260 : 360
    }

    private var artwork: some View {
        ArtworkView(url: song.artworkURL(pixelSize: 600), cornerRadius: 16)
            .frame(maxWidth: artworkMaxWidth)
            .frame(maxWidth: usesSideBySideLayout ? nil : .infinity)
            .accessibilityLabel(SongAccessibility.artworkLabel(for: song))
            .accessibilityAddTraits(.isImage)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(song.artist)
                    .font(.headline)
                    .foregroundStyle(.mutedText)
            }
            .accessibilityElement(children: .combine)

            Divider()

            DetailRow(title: "Album", value: formatter.album(of: song))
            DetailRow(title: "Genre", value: formatter.genre(of: song))
            DetailRow(title: "Released", value: formatter.releaseDate(of: song))
            if let duration = formatter.duration(of: song) {
                DetailRow(title: "Duration", value: duration)
            }
            DetailRow(title: "Price", value: formatter.price(of: song))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Label/value pair. Side by side normally; stacked at accessibility text sizes so neither side is squeezed.
private struct DetailRow: View {
    let title: LocalizedStringKey
    let value: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))

        layout {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.mutedText)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Text(value)
                .font(.body)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SongDetailView(
            song: Song(
                id: 1,
                title: "Bohemian Rhapsody",
                artist: "Queen",
                album: "The Platinum Collection",
                genre: "Rock",
                releaseDate: Date(timeIntervalSince1970: 183_297_600),
                price: 1.29,
                currencyCode: "USD",
                durationMilliseconds: 355_145
            )
        )
    }
}
