import Foundation
import Testing
@testable import Domain
@testable import Presentation
@testable import TestSupport

/// Guards the String Catalog: both languages complete and consistent.
/// The compiled catalog ships as `<language>.lproj/Localizable.strings` inside the Presentation module's resource bundle.
@Suite("Localization")
struct LocalizationTests {

    private func table(for language: String) throws -> [String: String] {
        let path = try #require(
            Bundle.presentation.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
            "Missing Localizable.strings for \(language)"
        )
        return try #require(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    /// Format specifiers (`%@`, `%lld`, `%1$@`…) in order, ignoring positional indexes.
    private func specifiers(in text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(lld|@|d)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    @Test("Unit tests run with English as the app language, so text assertions are deterministic")
    func testsRunInEnglish() {
        #expect(Bundle.presentation.preferredLocalizations.first == "en")
    }

    @Test("The app ships English and Spanish")
    func appShipsBothLanguages() {
        let languages = Set(Bundle.presentation.localizations)

        #expect(languages.contains("en"))
        #expect(languages.contains("es"))
    }

    @Test("Spanish has exactly the same keys as English")
    func sameKeysInBothLanguages() throws {
        let english = try table(for: "en")
        let spanish = try table(for: "es")

        #expect(!english.isEmpty)
        #expect(Set(english.keys) == Set(spanish.keys))
    }

    @Test("Every Spanish translation is filled in")
    func spanishTranslationsAreNotEmpty() throws {
        let spanish = try table(for: "es")

        let empty = spanish.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys
        #expect(empty.isEmpty, "Empty Spanish translations: \(empty.sorted())")
    }

    @Test("Spanish keeps the same format specifiers as English, so interpolation never breaks")
    func specifiersMatch() throws {
        let english = try table(for: "en")
        let spanish = try table(for: "es")

        let mismatched = english.keys.filter { key in
            specifiers(in: english[key] ?? "") != specifiers(in: spanish[key] ?? "")
        }
        #expect(mismatched.isEmpty, "Specifier mismatch in: \(mismatched.sorted())")
    }

    @Test("Spot checks: real Spanish text for the strings VoiceOver speaks")
    func spanishSpotChecks() throws {
        let spanish = try table(for: "es")

        #expect(spanish["%@, by %@"] == "%@, de %@")
        #expect(spanish["Free"] == "Gratis")
        #expect(spanish["Double tap to view song details"] == "Toca dos veces para ver los detalles de la canción")
        #expect(spanish["Searches again with the same text"] == "Repite la búsqueda con el mismo texto")
    }
}
