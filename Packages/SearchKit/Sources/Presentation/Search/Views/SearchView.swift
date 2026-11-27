import Domain
import SwiftUI

/// Search screen: native search field plus one clearly distinct view per `SearchViewState`.
public struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Songs", bundle: .module))
                .navigationDestination(for: Song.self) { song in
                    SongDetailView(song: song)
                }
                // With regular width (iPad) the default placement is a small floating field in the top-right
                // corner, so it is pinned under the title there. With compact width the default placement is
                // kept: it is the one that passes the accessibility audit at every Dynamic Type size.
                .searchable(
                    text: $viewModel.searchText,
                    placement: searchPlacement,
                    prompt: Text("Search songs or artists...", bundle: .module)
                )
                .onSubmit(of: .search) {
                    viewModel.submit()
                }
        }
    }

    private var searchPlacement: SearchFieldPlacement {
        horizontalSizeClass == .regular ? .navigationBarDrawer(displayMode: .always) : .automatic
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ScrollableStateView {
                ContentUnavailableView {
                    Label {
                        Text("Search for music", bundle: .module)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "music.note.list")
                    }
                } description: {
                    Text("Type a song or artist name to start.", bundle: .module)
                        .foregroundStyle(.mutedText)
                }
            }
        case .loading:
            ProgressView {
                Text("Searching songs…", bundle: .module)
            }
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
                    Label {
                        Text("Something went wrong", bundle: .module)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        viewModel.retry()
                    } label: {
                        Text("Retry", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(SongAccessibility.retryHint)
                }
            }
        }
    }
}
