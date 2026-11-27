//
//  iTunesSearchAppUITests.swift
//  iTunesSearchAppUITests
//
//  UI tests use XCTest (the only exception to the Swift Testing rule: XCUIAutomation requires it).
//  The app runs offline against `StubbedSearchSongsUseCase` via the `-UITestStubbedSearch` argument,
//  and in English so the texts these tests look for are stable. The one exception is
//  `testAppIsLocalizedInSpanish`, which guards the Spanish localization end to end.
//

import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {

    private let searchPrompt = "Search songs or artists..."
    private let welcomeTitle = "Search for music"
    private let firstSongLabel = "Bohemian Rhapsody, by Queen"
    private let secondSongLabel = "Don't Stop Me Now, by Queen"
    private let retryButton = "Retry"
    private let detailAlbum = "The Platinum Collection"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestStubbedSearch", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields[searchPrompt]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The search field must exist")
        field.tap()
        field.typeText(text)
    }

    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    /// Runs Apple's accessibility audit. Issues whose element sits inside two areas owned by iOS itself are
    /// exempt, because the app can not change them: the system search field (with its clear button) and the
    /// keyboard (with the prediction bar just above it). They are recognised by position and not by class name,
    /// which differs between iOS versions. Every other issue, anywhere else on screen, still fails the test.
    private func audit(_ app: XCUIApplication, for types: XCUIAccessibilityAuditType = .all) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            guard let element = issue.element else { return false }
            let frame = element.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)

            let searchField = app.searchFields.firstMatch
            if searchField.exists, searchField.frame.insetBy(dx: -24, dy: -24).contains(center) { return true }

            let keyboard = app.keyboards.firstMatch
            if keyboard.exists, keyboard.frame.insetBy(dx: 0, dy: -60).contains(center) { return true }

            return false
        }
    }

    // MARK: - Audits

    func testWelcomeScreenPassesAccessibilityAudit() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts[welcomeTitle].waitForExistence(timeout: 20))

        try audit(app)
    }

    func testResultsListPassesAccessibilityAudit() throws {
        let app = launchApp()
        search("queen", in: app)
        XCTAssertTrue(element(labeled: firstSongLabel, in: app).waitForExistence(timeout: 20))

        try audit(app)
    }

    func testDetailScreenPassesAccessibilityAudit() throws {
        let app = launchApp()
        search("queen", in: app)
        let row = element(labeled: firstSongLabel, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.staticTexts[detailAlbum].waitForExistence(timeout: 20))

        try audit(app)
    }

    // MARK: - VoiceOver structure

    func testEachResultIsOneElementWithTitleAndArtist() throws {
        let app = launchApp()
        search("queen", in: app)

        XCTAssertTrue(element(labeled: firstSongLabel, in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element(labeled: secondSongLabel, in: app).exists)
    }

    func testEmptyResultsPassAccessibilityAudit() throws {
        let app = launchApp()
        search("zzzz", in: app)

        // The system's "no results" view has its own localized text; wait for the welcome view to go away.
        XCTAssertTrue(app.staticTexts[welcomeTitle].waitForNonExistence(timeout: 20))
        XCTAssertFalse(element(labeled: firstSongLabel, in: app).exists)
        try audit(app)
    }

    func testErrorStateOffersAnAccessibleRetryButton() throws {
        let app = launchApp()
        search("error", in: app)

        let retry = app.buttons[retryButton]
        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        XCTAssertTrue(retry.isHittable)
        try audit(app)
    }

    // MARK: - Localization

    /// The String Catalog lives in a package module, so nothing but a real launch proves the app
    /// actually shows Spanish: without `InfoPlist.xcstrings` the app silently stays in English.
    func testAppIsLocalizedInSpanish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestStubbedSearch", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Busca música"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.searchFields["Buscar canciones o artistas..."].exists)
    }

    // MARK: - Navigation

    func testTappingAResultOpensTheDetailAndBackReturnsToTheResults() throws {
        let app = launchApp()
        search("queen", in: app)
        let row = element(labeled: firstSongLabel, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 20))

        row.tap()
        XCTAssertTrue(app.staticTexts[detailAlbum].waitForExistence(timeout: 20))
        XCTAssertFalse(app.searchFields[searchPrompt].exists, "The detail screen replaces the search screen")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(labeled: firstSongLabel, in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(element(labeled: secondSongLabel, in: app).exists)
    }

    // MARK: - Dynamic Type

    func testWelcomeAndErrorAuditAtLargestAccessibilityTextSize() throws {
        let app = launchApp(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(app.staticTexts[welcomeTitle].waitForExistence(timeout: 20))
        try audit(app, for: [.dynamicType, .textClipped, .sufficientElementDescription])

        search("error", in: app)
        XCTAssertTrue(app.buttons[retryButton].waitForExistence(timeout: 20))
        try audit(app, for: [.dynamicType, .textClipped, .sufficientElementDescription])
    }

    func testResultsAndDetailAuditAtLargestAccessibilityTextSize() throws {
        let app = launchApp(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        // "long" returns only the song with very long texts, so its row is on screen at any text size.
        search("long", in: app)

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
