import AppKit
import XCTest
@testable import K2Updater

final class ToolbarExportMenuTests: XCTestCase {
    @MainActor func testEntireCapsuleIncludingArrowReceivesClicks() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
        let button = ToolbarExportMenuButton(frame: NSRect(x: 10, y: 10, width: 56, height: 40))
        host.addSubview(button)
        for point in [NSPoint(x: 11, y: 30), NSPoint(x: 38, y: 30), NSPoint(x: 60, y: 30), NSPoint(x: 65, y: 30)] {
            XCTAssertTrue(host.hitTest(point) === button)
        }
        XCTAssertFalse(host.hitTest(NSPoint(x: 67, y: 30)) === button)
    }
    @MainActor func testExportSelectionUsesCurrentActionsAndRespectsDisabledEntries() {
        let coordinator = ToolbarExportMenu.Coordinator()
        var selections: [String] = []
        coordinator.items = [
            ToolbarExportMenuItem(title: "布局") { selections.append("layout") },
            ToolbarExportMenuItem(title: "背景", enabled: false) { selections.append("background") }
        ]
        let item = NSMenuItem()
        item.tag = 0
        coordinator.selectItem(item)
        item.tag = 1
        coordinator.selectItem(item)
        XCTAssertEqual(selections, ["layout"])
        coordinator.items = [ToolbarExportMenuItem(title: "开机图") { selections.append("startup") }]
        item.tag = 0
        coordinator.selectItem(item)
        XCTAssertEqual(selections, ["layout", "startup"])
    }
}
