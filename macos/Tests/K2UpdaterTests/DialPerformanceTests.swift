import AppKit
import SwiftUI
import XCTest
@testable import K2Updater

final class DialPerformanceTests: XCTestCase {
    @MainActor
    func testLayoutAndRepeatedCoordinateEdits() throws {
        guard ProcessInfo.processInfo.environment["K2_DIAL_PERFORMANCE"] == "1" else { return }
        for width: CGFloat in [620, 1100] {
            let picture = PictureStore()
            let start = Date()
            let hosting = NSHostingView(rootView: PictureView(picture: picture, store: UpdaterStore(), startup: false))
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 650),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            hosting.layoutSubtreeIfNeeded()
            let initial = Date().timeIntervalSince(start)
            let editStart = Date()
            let editing = DialElementEditing(picture: picture, elementID: 0)
            let group = UUID()
            for coordinate in 1...30 {
                editing.setCoordinate(coordinate, xAxis: true, group: group)
                RunLoop.main.run(until: Date().addingTimeInterval(0.001))
                hosting.layoutSubtreeIfNeeded()
            }
            print("Dial performance width=\(Int(width)): initial=\(initial)s, 30 edits=\(Date().timeIntervalSince(editStart))s")
            XCTAssertEqual(picture.project.layout.element(0).x, 30)
            picture.undo()
            XCTAssertEqual(picture.project.layout.element(0).x, 12)
        }
    }
}
