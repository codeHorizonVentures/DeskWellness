import XCTest
@testable import DeskWellness

final class FrontCheckInPresentationTests: XCTestCase {
    func testDetectingStateExplainsPhoneSetup() {
        let presentation = FrontCheckInPresentation.make(
            isLocked: false,
            heldSeconds: 0,
            holdDuration: 3,
            timedOut: false
        )

        XCTAssertEqual(presentation.phase, .detecting)
        XCTAssertEqual(presentation.title, "Set your phone down and step back")
        XCTAssertEqual(presentation.chipText, "GET READY")
        XCTAssertNil(presentation.progress)
    }

    func testAlignedStateAppearsBeforeHoldProgressStarts() {
        let presentation = FrontCheckInPresentation.make(
            isLocked: true,
            heldSeconds: 0,
            holdDuration: 3,
            timedOut: false
        )

        XCTAssertEqual(presentation.phase, .aligned)
        XCTAssertEqual(presentation.title, "Aligned")
        XCTAssertEqual(presentation.secondsRemaining, 3)
        XCTAssertEqual(presentation.progress, 0)
    }

    func testHoldingStateShowsRemainingSecondsAndProgress() {
        let presentation = FrontCheckInPresentation.make(
            isLocked: true,
            heldSeconds: 1,
            holdDuration: 3,
            timedOut: false
        )

        XCTAssertEqual(presentation.phase, .holding)
        XCTAssertEqual(presentation.chipText, "HOLD 2S")
        XCTAssertEqual(presentation.secondsRemaining, 2)
        XCTAssertNotNil(presentation.progress)
        XCTAssertEqual(presentation.progress ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testTimeoutStateOffersRetryLanguage() {
        let presentation = FrontCheckInPresentation.make(
            isLocked: false,
            heldSeconds: 0,
            holdDuration: 3,
            timedOut: true
        )

        XCTAssertEqual(presentation.phase, .timeout)
        XCTAssertEqual(presentation.title, "Could not lock this time")
        XCTAssertEqual(presentation.chipText, "TRY AGAIN")
        XCTAssertNil(presentation.progress)
    }
}
