import SwiftUI

/// One row of the results list. Artwork next to the text; stacked vertically at accessibility text sizes.
struct SongRowView: View {
    let song: Song

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var artworkSize: CGFloat = 56

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            ArtworkView(url: song.artworkURL)
                .frame(width: artworkSize, height: artworkSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(SongAccessibility.rowLabel(for: song))
        .accessibilityHint(SongAccessibility.rowHint)
        // Voice Control: "Tap Bohemian Rhapsody" must work even though the spoken label also has the artist.
        .accessibilityInputLabels([song.title])
        .accessibilityIdentifier("songRow")
    }
}
