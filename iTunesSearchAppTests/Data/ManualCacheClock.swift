import os
@testable import Data
@testable import Domain

/// Test clock that only moves when told to, so TTL expiration is tested in microseconds.
final class ManualCacheClock: CacheClock, Sendable {
    private let elapsed = OSAllocatedUnfairLock(initialState: Duration.zero)

    var now: Duration {
        elapsed.withLock { $0 }
    }

    func advance(by duration: Duration) {
        elapsed.withLock { $0 += duration }
    }
}
