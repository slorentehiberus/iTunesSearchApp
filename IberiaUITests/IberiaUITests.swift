//
//  IberiaUITests.swift
//  IberiaUITests
//
//  UI tests use XCTest (the only exception to the Swift Testing rule: XCUIAutomation requires it).
//  The app runs offline against `StubbedSearchSongsUseCase` via the `-UITestStubbedSearch` argument,
//  and always in English so the texts these tests look for are stable.
//

import XCTest

@MainActor
final class IberiaAccessibilityUITests: XCTestCase {

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
