import XCTest

final class JournalModelsTests: XCTestCase {
    func testWorkoutPresentationUsesResetLanguage() {
        XCTAssertEqual(JournalPresentation.title(for: .workout), "Desk Reset")
        XCTAssertEqual(
            JournalPresentation.statusText(for: .workout, exercisesCompleted: true),
            "Reset completed"
        )
    }

    func testScanPresentationKeepsCheckInsOptional() {
        XCTAssertEqual(JournalPresentation.title(for: .scan), "Optional Check-In")
        XCTAssertEqual(
            JournalPresentation.statusText(for: .scan, exercisesCompleted: false),
            "Check-in saved"
        )
    }

    func testWeeklySummaryCountsCompletedResetsAndCheckInsForCurrentWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1_712_304_000) // 2024-04-10 00:00:00 UTC

        let entries = [
            ResetConsistencyEntry(date: now, kind: .workout, exercisesCompleted: true),
            ResetConsistencyEntry(date: now.addingTimeInterval(-3_600), kind: .workout, exercisesCompleted: false),
            ResetConsistencyEntry(date: now.addingTimeInterval(-86_400), kind: .workout, exercisesCompleted: true),
            ResetConsistencyEntry(date: now.addingTimeInterval(-172_800), kind: .scan, exercisesCompleted: false),
            ResetConsistencyEntry(date: now.addingTimeInterval(-604_800), kind: .workout, exercisesCompleted: true)
        ]

        let summary = ResetConsistencySummary.build(from: entries, now: now, calendar: calendar, weeklyGoal: 3)

        XCTAssertEqual(summary.completedResets, 2)
        XCTAssertEqual(summary.loggedResets, 3)
        XCTAssertEqual(summary.checkIns, 1)
        XCTAssertEqual(summary.activeDays, 2)
        XCTAssertEqual(summary.remainingResets, 1)
        XCTAssertFalse(summary.hasReachedGoal)
    }

    func testWeeklySummaryMarksGoalReached() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1_712_304_000)
        let entries = [
            ResetConsistencyEntry(date: now, kind: .workout, exercisesCompleted: true),
            ResetConsistencyEntry(date: now.addingTimeInterval(-86_400), kind: .workout, exercisesCompleted: true),
            ResetConsistencyEntry(date: now.addingTimeInterval(-172_800), kind: .workout, exercisesCompleted: true)
        ]

        let summary = ResetConsistencySummary.build(from: entries, now: now, calendar: calendar, weeklyGoal: 3)

        XCTAssertTrue(summary.hasReachedGoal)
        XCTAssertEqual(summary.headline, "Weekly goal reached")
        XCTAssertEqual(summary.progressFraction, 1)
    }
}
