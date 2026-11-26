/// Injectable monotonic time source for cache expiration.
///
/// `now` is the time elapsed since an arbitrary fixed origin. Only differences between two
/// readings matter. Tests inject a manual implementation to move time in milliseconds.
protocol CacheClock: Sendable {
    var now: Duration { get }
}

/// Production implementation backed by `ContinuousClock`.
struct SystemCacheClock: CacheClock {
    private let origin = ContinuousClock.now

    var now: Duration {
        origin.duration(to: ContinuousClock.now)
    }
}
