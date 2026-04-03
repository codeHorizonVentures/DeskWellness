import XCTest
import UserNotifications

final class ReminderAccessGuidanceTests: XCTestCase {
    func testNotDeterminedGuidancePromptsForPermission() {
        let guidance = ReminderAccessGuidance.make(status: .notDetermined, remindersEnabled: false)

        XCTAssertEqual(guidance.title, "Allow workday reminders")
        XCTAssertEqual(guidance.primaryAction, .requestPermission)
        XCTAssertEqual(guidance.primaryActionTitle, "Allow Notifications")
    }

    func testDeniedGuidanceFallsBackToSettings() {
        let guidance = ReminderAccessGuidance.make(status: .denied, remindersEnabled: true)

        XCTAssertEqual(guidance.title, "Notifications are off")
        XCTAssertEqual(guidance.primaryAction, .openSettings)
        XCTAssertTrue(guidance.showsSecondaryDismissAction)
    }

    func testAuthorizedGuidanceCanEnableReminders() {
        let guidance = ReminderAccessGuidance.make(status: .authorized, remindersEnabled: false)

        XCTAssertEqual(guidance.title, "Notifications are ready")
        XCTAssertEqual(guidance.primaryAction, .enableReminders)
        XCTAssertEqual(guidance.statusMessage, "Notifications are available. Weekday reminders are off.")
    }

    func testAuthorizedGuidanceShowsActiveState() {
        let guidance = ReminderAccessGuidance.make(status: .authorized, remindersEnabled: true)

        XCTAssertEqual(guidance.title, "Weekday reminders are active")
        XCTAssertNil(guidance.primaryAction)
        XCTAssertEqual(guidance.statusMessage, "Weekday reminders are scheduled.")
    }
}
