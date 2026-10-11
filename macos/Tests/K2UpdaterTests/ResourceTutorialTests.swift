import XCTest
import K2Core
@testable import K2Updater

final class ResourceTutorialTests: XCTestCase {
    func testEmarkTutorialHasNoCountdownOrWriteGate() {
        var gate = ResourceTutorialGate()
        XCTAssertTrue(gate.allows(.emark))
        gate.open(.emark, now: 100)
        XCTAssertEqual(gate.remaining(now: 100), 0)
        XCTAssertTrue(gate.confirm(now: 100))
        XCTAssertTrue(gate.allows(.emark))
        XCTAssertFalse(gate.allows(.layout))
        XCTAssertEqual(ResourceTutorialKind.emark.referenceURL.fragment?.removingPercentEncoding, "6-E-Marker类")
    }

    func testDialWaitsFiveSecondsAndRequiresExplicitConfirmation() {
        var gate = ResourceTutorialGate()
        gate.open(.dial, now: 100)
        XCTAssertEqual(gate.remaining(now: 100), 5)
        XCTAssertFalse(gate.confirm(now: 104.999))
        XCTAssertFalse(gate.allows(.layout))
        XCTAssertFalse(gate.allows(.background))
        XCTAssertEqual(gate.remaining(now: 105), 0)
        XCTAssertFalse(gate.allows(.layout))
        XCTAssertTrue(gate.confirm(now: 105))
        XCTAssertTrue(gate.allows(.layout))
        XCTAssertTrue(gate.allows(.background))
        XCTAssertFalse(gate.allows(.startup))
    }
    func testStartupWaitsThreeSecondsAndCancelDoesNotUnlockEitherPage() {
        var gate = ResourceTutorialGate()
        gate.open(.startup, now: 100)
        XCTAssertFalse(gate.confirm(now: 102.999))
        gate.cancel()
        XCTAssertFalse(gate.confirm(now: 103))
        XCTAssertFalse(gate.allows(.startup))
        gate.open(.startup, now: 200)
        XCTAssertFalse(gate.confirm(now: 202))
        XCTAssertTrue(gate.confirm(now: 203))
        XCTAssertTrue(gate.allows(.startup))
        XCTAssertFalse(gate.allows(.layout))
        XCTAssertTrue(gate.allows(.emark))
    }
    func testConfirmedTutorialsReopenWithoutCountdownIndependently() {
        for kind in ResourceTutorialKind.allCases {
            var gate = ResourceTutorialGate()
            gate.open(kind, now: 0)
            XCTAssertTrue(gate.confirm(now: kind.readingSeconds))
            gate.open(kind, now: 10)
            XCTAssertEqual(gate.remaining(now: 10), 0)
            gate.cancel()
            gate.open(kind, now: 11)
            XCTAssertTrue(gate.confirm(now: 11))
            let other: ResourceTutorialKind = kind == .dial ? .startup : .dial
            gate.open(other, now: 20)
            XCTAssertEqual(gate.remaining(now: 20), Int(other.readingSeconds))
            XCTAssertFalse(gate.confirm(now: 20))
        }
        XCTAssertFalse(ResourceTutorialGate().allows(.layout))
    }
    func testUnconfirmedReadingReopensWithFullCountdown() {
        var gate = ResourceTutorialGate()
        gate.open(.dial, now: 0)
        gate.cancel()
        gate.open(.dial, now: 10)
        XCTAssertEqual(gate.remaining(now: 10), 5)
        XCTAssertFalse(gate.confirm(now: 14))
        gate.cancel()
        gate.open(.dial, now: 20)
        XCTAssertEqual(gate.remaining(now: 20), 5)
    }
    @MainActor func testLayoutWithoutBackgroundStillRequiresTutorialAndDFU() {
        let store = UpdaterStore()
        XCTAssertTrue(store.canWriteDialLayoutInSequence(usesBackground: false))
        XCTAssertFalse(store.canWriteResource(.layout, usesDialBackground: false))
        store.writeResource(ResourceWriteIntent(kind: .layout, data: Data(), manifest: nil, manifestHash: nil), usesDialBackground: false)
        XCTAssertEqual(store.tutorialGate.presented, .dial)
        XCTAssertFalse(store.isBusy)
        XCTAssertFalse(store.dfuConfirmed)
    }
    @MainActor func testWriteAndRestoreCannotBypassTutorialGate() {
        let store = UpdaterStore()
        store.writeResource(ResourceWriteIntent(kind: .layout, data: Data(), manifest: nil, manifestHash: nil))
        XCTAssertEqual(store.tutorialGate.presented, .dial)
        XCTAssertFalse(store.isBusy)
        store.cancelResourceTutorial()
        store.writeResource(ResourceWriteIntent(kind: .startup, data: nil, manifest: URL(fileURLWithPath: "/invalid/manifest.json"), manifestHash: "test"))
        XCTAssertEqual(store.tutorialGate.presented, .startup)
        XCTAssertFalse(store.isBusy)
    }
}
