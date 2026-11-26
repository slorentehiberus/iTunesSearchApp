/// Speaks a message through VoiceOver. A protocol so tests can record messages instead of speaking them.
@MainActor
protocol AccessibilityAnnouncer {
    func announce(_ message: String)
}
