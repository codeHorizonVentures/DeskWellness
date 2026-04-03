import XCTest

final class ResetMinuteScreenshotUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureOnboarding() {
        let app = launchApp(arguments: ["-ResetMinuteForceOnboarding"])
        XCTAssertTrue(app.staticTexts["onboarding_screen"].waitForExistence(timeout: timeout))
        attachScreenshot(of: app, named: "01-onboarding")
    }

    @MainActor
    func testCaptureHomeWeeklyProgress() {
        let app = launchApp(arguments: ["-ResetMinuteSkipOnboarding", "-ResetMinuteDemoConsistency"])
        XCTAssertTrue(app.descendants(matching: .any)["home_weekly_progress"].waitForExistence(timeout: timeout))
        attachScreenshot(of: app, named: "02-home-weekly-progress")
    }

    @MainActor
    func testCaptureReminderSettings() {
        let app = launchApp(arguments: [
            "-ResetMinuteSkipOnboarding",
            "-ResetMinuteDemoConsistency",
            "-ResetMinuteOpenReminderSettings"
        ])

        XCTAssertTrue(app.descendants(matching: .any)["reminder_settings_screen"].waitForExistence(timeout: timeout))
        attachScreenshot(of: app, named: "03-reminder-settings")
    }

    @MainActor
    func testCaptureQuickReset() {
        let app = launchApp(arguments: ["-ResetMinuteSkipOnboarding", "-ResetMinuteDemoConsistency"])

        let startQuickReset = app.buttons["home_start_quick_reset"]
        XCTAssertTrue(startQuickReset.waitForExistence(timeout: timeout))
        startQuickReset.tap()

        XCTAssertTrue(app.staticTexts["desk_reset_screen"].waitForExistence(timeout: timeout))
        attachScreenshot(of: app, named: "04-quick-reset")
    }

    @MainActor
    func testCaptureJournal() {
        let app = launchApp(arguments: [
            "-ResetMinuteSkipOnboarding",
            "-ResetMinuteDemoConsistency",
            "-ResetMinuteOpenJournal",
            "-ResetMinuteDemoJournalEntries"
        ])

        XCTAssertTrue(app.descendants(matching: .any)["journal_screen"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: timeout))
        attachScreenshot(of: app, named: "05-journal")
    }

    @MainActor
    private func launchApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
