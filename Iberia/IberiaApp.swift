//
//  IberiaApp.swift
//  Iberia
//
//  Created by Sara Lorente on 25/11/2026.
//

import SwiftUI
import Foundation

/// Composition root: the only place that knows every layer and wires the dependency graph.
@main
struct IberiaApp: App {
    @State private var viewModel: SearchViewModel

    init() {
        _viewModel = State(initialValue: SearchViewModel(searchSongs: Self.makeSearchSongsUseCase()))
    }

    private static func makeSearchSongsUseCase() -> any SearchSongsUseCase {
        #if DEBUG
        // UI tests run offline against a fixed set of songs.
        if ProcessInfo.processInfo.arguments.contains("-UITestStubbedSearch") {
            return StubbedSearchSongsUseCase()
        }
        #endif

        let httpClient = URLSessionHTTPClient()
        let dataSource = ITunesSongRemoteDataSource(httpClient: httpClient)
        let remoteRepository = RemoteSongRepository(dataSource: dataSource)
        let cachedRepository = CachedSongRepository(
            base: remoteRepository,
            cache: SongMemoryCache()
        )
        return DefaultSearchSongsUseCase(repository: cachedRepository)
    }

    var body: some Scene {
        WindowGroup {
            SearchView(viewModel: viewModel)
        }
    }
}
