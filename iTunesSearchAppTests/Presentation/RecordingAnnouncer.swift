@testable import Presentation

/// Test double for `AccessibilityAnnouncer`: keeps the messages instead of speaking them.
@MainActor
final class RecordingAnnouncer: AccessibilityAnnouncer {
    private(set) var messages: [String] = []

    func announce(_ message: String) {
        messages.append(message)
    }
}
