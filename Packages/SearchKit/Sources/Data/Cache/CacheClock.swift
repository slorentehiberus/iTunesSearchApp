import Domain

/// Injectable monotonic time source for cache expiration.
///
/// `now` is the time elapsed since an arbitrary fixed origin. Only differences between two
/// readings matter. Tests inject a manual implementation to move time in milliseconds.
public protocol CacheClock: Sendable {
    var now: Duration { get }
}

/// Production implementation backed by `ContinuousClock`.
public struct SystemCacheClock: CacheClock {
    public init() {}

    private let origin = ContinuousClock.now

    public var now: Duration {
        origin.duration(to: ContinuousClock.now)
    }
}
