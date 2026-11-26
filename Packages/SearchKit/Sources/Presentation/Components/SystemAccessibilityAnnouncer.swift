import SwiftUI

/// The real announcer: posts an `AccessibilityNotification.Announcement`.
struct SystemAccessibilityAnnouncer: AccessibilityAnnouncer {
    func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
