import XCTest
import K2Core
@testable import K2Updater

final class DialWriteSequenceTests: XCTestCase {
    func testLayoutRequiresSuccessfulBackgroundOnSameDevice() {
        var sequence = DialWriteSequence()
        XCTAssertFalse(sequence.allows(.layout, device: "A"))
        XCTAssertTrue(sequence.allows(.background, device: "A"))
        XCTAssertTrue(sequence.allows(.startup, device: "A"))
        sequence.started(.background)
        sequence.completed(.background, device: "A", succeeded: false)
        XCTAssertFalse(sequence.allows(.layout, device: "A"))
        sequence.completed(.background, device: "A", succeeded: true)
        XCTAssertTrue(sequence.allows(.layout, device: "A"))
        XCTAssertFalse(sequence.allows(.layout, device: "B"))
        sequence.completed(.layout, device: "A", succeeded: false)
        XCTAssertTrue(sequence.allows(.layout, device: "A"))
        sequence.completed(.layout, device: "A", succeeded: true)
        XCTAssertFalse(sequence.allows(.layout, device: "A"))
    }
    func testOptionalBackgroundOnlySkipsTheBackgroundPrerequisite() {
        var sequence = DialWriteSequence()
        XCTAssertTrue(sequence.allows(.layout, device: "A", usesBackground: false))
        XCTAssertFalse(sequence.allows(.background, device: "A", usesBackground: false))
        XCTAssertTrue(sequence.allows(.startup, device: "A", usesBackground: false))
        XCTAssertFalse(sequence.allows(.layout, device: "A", usesBackground: true))
        sequence.completed(.background, device: "A", succeeded: true)
        XCTAssertTrue(sequence.allows(.layout, device: "A", usesBackground: true))
        XCTAssertTrue(sequence.allows(.layout, device: "B", usesBackground: false))
        XCTAssertFalse(sequence.allows(.layout, device: "B", usesBackground: true))
    }
    func testReplacementBackgroundAndFirmwareResetRevokeLayoutPermission() {
        var sequence = DialWriteSequence()
        sequence.completed(.background, device: "A", succeeded: true)
        sequence.started(.background)
        sequence.completed(.background, device: "A", succeeded: false)
        XCTAssertFalse(sequence.allows(.layout, device: "A"))
        sequence.completed(.background, device: "A", succeeded: true)
        sequence.completed(.startup, device: "A", succeeded: true)
        XCTAssertTrue(sequence.allows(.layout, device: "A"))
        sequence.reset()
        XCTAssertFalse(sequence.allows(.layout, device: "A"))
    }
}
