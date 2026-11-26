/// Yields to other tasks until `condition` holds. Bounded, so a broken test fails instead of hanging.
/// It waits on state, never on wall-clock time.
nonisolated(nonsending) func waitUntil(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<100_000 {
        if await condition() { return true }
        await Task.yield()
    }
    return false
}

/// Gives pending tasks a chance to run, to check that something does NOT happen.
nonisolated(nonsending) func settle(yields: Int = 100) async {
    for _ in 0..<yields {
        await Task.yield()
    }
}
