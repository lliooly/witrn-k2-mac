import XCTest
import K2Core
@testable import K2Updater

final class PictureProjectNameTests: XCTestCase {
    @MainActor func testRenameUndoAndSavedProjectRoundTrip() throws {
        let store = PictureStore()
        XCTAssertEqual(store.projectName, "我的 K2 工程")
        XCTAssertFalse(store.dirty)
        store.renameProject("  星空  ")
        XCTAssertEqual(store.projectName, "星空")
        XCTAssertTrue(store.dirty)
        store.undo()
        XCTAssertEqual(store.projectName, "我的 K2 工程")
        XCTAssertFalse(store.dirty)
        store.redo()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".k2project")
        defer { try? FileManager.default.removeItem(at: url) }
        store.projectURL = url
        XCTAssertTrue(store.save())
        let reopened = PictureStore()
        reopened.open(url)
        XCTAssertEqual(reopened.projectName, "星空")
        XCTAssertFalse(reopened.dirty)
        XCTAssertEqual(reopened.project.layout, store.project.layout)
    }
    @MainActor func testLegacyProjectsRemainReadableAndUnchangedOnUneditedNameCommit() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: PictureProject().encoded()) as? [String: Any])
        json.removeValue(forKey: "name")
        let data = try JSONSerialization.data(withJSONObject: json)
        let project = try PictureProject.decode(data)
        XCTAssertNil(project.name)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("旧表盘.k2project")
        try data.write(to: url)
        let store = PictureStore()
        store.open(url)
        XCTAssertEqual(store.projectName, "旧表盘")
        store.renameProject(store.projectName)
        XCTAssertFalse(store.dirty)
        XCTAssertNil(store.project.name)
        store.renameProject("  ")
        XCTAssertEqual(store.projectName, "旧表盘")
    }
}
