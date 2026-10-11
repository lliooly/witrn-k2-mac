import AppKit
import SwiftUI
import XCTest
@testable import K2Updater
import K2Core

final class EmarkPerformanceTests: XCTestCase {
    @MainActor
    func testPopupSelectionAndDisabledStateTrackModel() {
        let emark = EmarkStore()
        emark.add()
        let current = EmarkField.cable.first { $0.id == "current" }!
        let updater = UpdaterStore()
        let hosting = NSHostingView(rootView: EmarkView(emark: emark, store: updater))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 790, height: 880),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        func settle() {
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            hosting.layoutSubtreeIfNeeded()
        }
        func popups(_ view: NSView) -> [NSPopUpButton] {
            (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popups)
        }
        settle()
        let control = popups(hosting).first { $0.accessibilityLabel() == current.title }
        XCTAssertNotNil(control)
        XCTAssertEqual(control?.indexOfSelectedItem, 2)
        emark.update { try $0.set(current, value: 1) }
        settle()
        XCTAssertEqual(control?.indexOfSelectedItem, 1)
        emark.undo()
        settle()
        XCTAssertEqual(control?.indexOfSelectedItem, 2)
        updater.isBusy = true
        settle()
        XCTAssertEqual(control?.isEnabled, false)
        updater.isBusy = false
        settle()
        XCTAssertEqual(control?.isEnabled, true)
    }

    @MainActor
    func testSidebarWidthChangesPreserveEditorControls() throws {
        guard ProcessInfo.processInfo.environment["K2_EMARK_PERFORMANCE"] == "1" else { return }
        let emark = EmarkStore()
        for _ in 0..<EmarkBank.capacity { emark.add() }
        let original = emark.bank
        _ = emark.textEdited("vid", text: "XYZ", group: UUID()) {
            try $0.setWord(25, EmarkStore.number($1, hexadecimal: true))
        }
        let updater = UpdaterStore()
        let hosting = NSHostingView(rootView: EmarkView(emark: emark, store: updater))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 790, height: 880),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hosting.layoutSubtreeIfNeeded()

        func popupIDs(_ view: NSView) -> Set<ObjectIdentifier> {
            let own = view is NSPopUpButton ? Set([ObjectIdentifier(view)]) : []
            return view.subviews.reduce(own) { $0.union(popupIDs($1)) }
        }
        let initialControls = popupIDs(hosting)
        var allControls = initialControls
        var samples: [TimeInterval] = []
        for frame in 0..<60 {
            let phase = CGFloat(frame % 30) / 29
            let width = frame < 30 ? 790 + 261 * phase : 1051 - 261 * phase
            let start = ProcessInfo.processInfo.systemUptime
            window.setContentSize(CGSize(width: width, height: 880))
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.001))
            hosting.layoutSubtreeIfNeeded()
            samples.append(ProcessInfo.processInfo.systemUptime - start)
            allControls.formUnion(popupIDs(hosting))
        }
        let sorted = samples.sorted()
        print("E-Mark resize: total=\(samples.reduce(0, +))s, median=\(sorted[30] * 1000)ms, p95=\(sorted[56] * 1000)ms, initial popups=\(initialControls.count), unique popups=\(allControls.count)")
        XCTAssertEqual(emark.bank, original)
        XCTAssertEqual(emark.selected, 9)
        XCTAssertEqual(emark.invalidDrafts["vid"], "XYZ")
        XCTAssertEqual(emark.invalidFields, ["vid"])
        // Across responsive breakpoints the same native editors should survive.
        if ProcessInfo.processInfo.environment["K2_EMARK_BASELINE"] != "1" {
            XCTAssertEqual(allControls, initialControls)
        }
    }
}
