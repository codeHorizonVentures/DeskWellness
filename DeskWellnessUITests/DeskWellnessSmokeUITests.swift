import XCTest

final class DeskWellnessSmokeUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeCanStartQuickReset() {
        let app = XCUIApplication()
        app.launchArguments += ["-ResetMinuteForceOnboarding"]
        app.launch()

        let onboardingContinue = app.buttons["onboarding_continue"]
        XCTAssertTrue(onboardingContinue.waitForExistence(timeout: timeout))
        onboardingContinue.tap()

        let startQuickReset = app.buttons["home_start_quick_reset"]
        XCTAssertTrue(startQuickReset.waitForExistence(timeout: timeout))
        startQuickReset.tap()

        XCTAssertTrue(app.staticTexts["desk_reset_screen"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["desk_reset_skip_button"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testCompletedQuickResetAppearsInJournal() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ResetMinuteSkipOnboarding",
            "-ResetMinuteDeleteAllEntries"
        ]
        app.launch()

        let startQuickReset = app.buttons["home_start_quick_reset"]
        XCTAssertTrue(startQuickReset.waitForExistence(timeout: timeout))
        startQuickReset.tap()

        for _ in 0..<3 {
            let skipButton = app.buttons["desk_reset_skip_button"]
            XCTAssertTrue(skipButton.waitForExistence(timeout: timeout))
            skipButton.tap()
        }

        let doneButton = app.buttons["desk_reset_completion_done_button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: timeout))
        doneButton.tap()

        let openJournal = app.buttons["home_open_reset_journal"]
        XCTAssertTrue(openJournal.waitForExistence(timeout: timeout))
        openJournal.tap()

        XCTAssertTrue(app.descendants(matching: .any)["journal_screen"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Desk Reset"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Reset completed"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testOptionalCheckInShowsRecoveryActionsWhenCameraAccessIsDenied() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ResetMinuteSkipOnboarding",
            "-ResetMinuteSimulateCameraDenied"
        ]
        app.launch()

        let optionalCheckIn = app.buttons["home_optional_check_in"]
        XCTAssertTrue(optionalCheckIn.waitForExistence(timeout: timeout))
        optionalCheckIn.tap()

        let alert = app.alerts["Camera Access Required"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        XCTAssertTrue(alert.buttons["Not Now"].exists)
        XCTAssertTrue(alert.buttons["Open Settings"].exists)
    }

    @MainActor
    func testOptionalCheckInShowsRecoveryActionsAfterFirstRequestDenial() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ResetMinuteSkipOnboarding",
            "-ResetMinuteSimulateCameraRequestDenied"
        ]
        app.launch()

        let optionalCheckIn = app.buttons["home_optional_check_in"]
        XCTAssertTrue(optionalCheckIn.waitForExistence(timeout: timeout))
        optionalCheckIn.tap()

        let alert = app.alerts["Camera Access Required"]
        XCTAssertTrue(alert.waitForExistence(timeout: timeout))
        XCTAssertTrue(alert.buttons["Not Now"].exists)
        XCTAssertTrue(alert.buttons["Open Settings"].exists)
    }
}
