//
//  IberiaUITests.swift
//  IberiaUITests
//
//  UI tests use XCTest (the only exception to the Swift Testing rule: XCUIAutomation requires it).
//  The app runs offline against `StubbedSearchSongsUseCase` via the `-UITestStubbedSearch` argument.
//  Every test runs twice: `IberiaAccessibilityUITests` in English and its subclass in Spanish.
//

import XCTest

/// Texts the UI tests look for, per language.
struct UITestStrings {
    let languageArguments: [String]
    let searchPrompt: String
    let welcomeTitle: String
    let firstSongLabel: String
    let secondSongLabel: String
    let retryButton: String
    let detailAlbum: String

    static let english = UITestStrings(
        languageArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"],
        searchPrompt: "Search songs or artists...",
        welcomeTitle: "Search for music",
        firstSongLabel: "Bohemian Rhapsody, by Queen",
        secondSongLabel: "Don't Stop Me Now, by Queen",
        retryButton: "Retry",
        detailAlbum: "The Platinum Collection"
    )

    static let spanish = UITestStrings(
        languageArguments: ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"],
        searchPrompt: "Buscar canciones o artistas...",
        welcomeTitle: "Busca música",
        firstSongLabel: "Bohemian Rhapsody, de Queen",
        secondSongLabel: "Don't Stop Me Now, de Queen",
        retryButton: "Reintentar",
        detailAlbum: "The Platinum Collection"
    )
}

@MainActor
class IberiaAccessibilityUITests: XCTestCase {

    /// Overridden by the Spanish subclass.
    var strings: UITestStrings { .english }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestStubbedSearch"] + strings.languageArguments
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields[strings.searchPrompt]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The search field must exist")
        field.tap()
        field.typeText(text)
    }

    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    /// Runs Apple's accessibility audit. Only two controls owned by iOS itself are exempt, because the app
    /// can not change them: the search field's clear button and the keyboard's prediction bar.
    /// Every other issue, including any other hit-area or description problem, still fails the test.
    private func audit(_ app: XCUIApplication, for types: XCUIAccessibilityAuditType = .all) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            let description = issue.detailedDescription
            return description.contains("_UITextFieldClearButton")
                || description.contains("TUIPredictionViewCell")
        }
    }

    // MARK: - Audits

    func testWelcomeScreenPassesAccessibilityAudit() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts[strings.welcomeTitle].waitForExistence(timeout: 20))

        try audit(app)
    }

    func testResultsListPassesAccessibilityAudit() throws {
        let app = launchApp()
        search("queen", in: app)
        XCTAssertTrue(element(labeled: strings.firstSongLabel, in: app).waitForExistence(timeout: 20))

        try audit(app)
    }

    func testDetailScreenPassesAccessibilityAudit() throws {
        let app = launchApp()
        search("queen", in: app)
        let row = element(labeled: strings.firstSongLabel, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.staticTexts[strings.detailAlbum].waitForExistence(timeout: 20))

        try audit(app)
    }

    // MARK: - VoiceOver structure

    func testEachResultIsOneElementWithTitleAndArtist() throws {
        let app = launchApp()
        search("queen", in: app)

        XCTAssertTrue(element(labeled: strings.firstSongLabel, in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element(labeled: strings.secondSongLabel, in: app).exists)
    }

    func testEmptyResultsPassAccessibilityAudit() throws {
        let app = launchApp()
        search("zzzz", in: app)

        // The system's "no results" view has its own localized text; wait for the list to be absent.
        XCTAssertTrue(app.staticTexts[strings.welcomeTitle].waitForNonExistence(timeout: 20))
        XCTAssertFalse(element(labeled: strings.firstSongLabel, in: app).exists)
        try audit(app)
    }

    func testErrorStateOffersAnAccessibleRetryButton() throws {
        let app = launchApp()
        search("error", in: app)

        let retry = app.buttons[strings.retryButton]
        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        XCTAssertTrue(retry.isHittable)
        try audit(app)
    }

    // MARK: - Dynamic Type

    func testResultsAndDetailAuditAtLargestAccessibilityTextSize() throws {
        let app = launchApp(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        search("queen", in: app)

        let longTitleRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "A Very Long Song Title"))
            .firstMatch
        XCTAssertTrue(longTitleRow.waitForExistence(timeout: 20))
        try audit(app, for: [.dynamicType, .textClipped, .sufficientElementDescription])

        longTitleRow.tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 20))
        try audit(app, for: [.dynamicType, .textClipped, .sufficientElementDescription])
    }
}

/// The same accessibility tests, with the app running in Spanish.
@MainActor
final class IberiaAccessibilitySpanishUITests: IberiaAccessibilityUITests {
    override var strings: UITestStrings { .spanish }
}
