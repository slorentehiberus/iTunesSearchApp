/// Song search use case, consumed by Presentation.
protocol SearchSongsUseCase: Sendable {
    /// - Returns: songs unique by `id` in their original order; `[]` if `query` is not valid.
    /// - Throws: `CancellationError` if the task is cancelled; `SearchError` for any other failure.
    func execute(query: String) async throws -> [Song]
}
