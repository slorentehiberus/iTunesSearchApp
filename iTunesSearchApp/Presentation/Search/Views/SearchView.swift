import SwiftUI
import UIKit

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
                // On iPad the default placement is a small floating field in the top-right corner, so it is
                // pinned under the title there. On iPhone the default placement is kept: it is the one that
                // passes the accessibility audit at every Dynamic Type size.
                .searchable(
                    text: $viewModel.searchText,
                    placement: Self.searchPlacement,
                    prompt: "Search songs or artists..."
                )
                .onSubmit(of: .search) {
                    viewModel.submit()
                }
                .onChange(of: viewModel.state) { _, newState in
                    announceIfError(newState)
                }
        }
    }

    private static var searchPlacement: SearchFieldPlacement {
        UIDevice.current.userInterfaceIdiom == .pad ? .navigationBarDrawer(displayMode: .always) : .automatic
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
            .readableContentWidth()
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

    /// VoiceOver focus stays in the search field while the search runs, so a failure would go unnoticed.
    /// Errors are the one state announced; results and empty states are found by exploring the screen.
    private func announceIfError(_ state: SearchViewState) {
        guard case .error(let message) = state else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}
