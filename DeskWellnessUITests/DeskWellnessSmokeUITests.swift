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
}
