import SwiftUI

/// Search screen: native search field plus one clearly distinct view per `SearchViewState`.
struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Songs")
                .navigationDestination(for: Song.self) { song in
                    SongDetailView(song: song)
                }
                .searchable(text: $viewModel.searchText, prompt: "Search songs or artists...")
                .onSubmit(of: .search) {
                    viewModel.submit()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ScrollableStateView {
                ContentUnavailableView(
                    "Search for music",
                    systemImage: "music.note.list",
                    description: Text("Type a song or artist name to start.")
                        .foregroundStyle(.mutedText)
                )
            }
        case .loading:
            ProgressView("Searching songs…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let songs):
            List(songs) { song in
                NavigationLink(value: song) {
                    SongRowView(song: song)
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("searchResultsList")
        case .empty:
            ScrollableStateView {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        case .error(let message):
            ScrollableStateView {
                ContentUnavailableView {
                    Label("Something went wrong", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        viewModel.retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(SongAccessibility.retryHint)
                }
            }
        }
    }
}
