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
}
