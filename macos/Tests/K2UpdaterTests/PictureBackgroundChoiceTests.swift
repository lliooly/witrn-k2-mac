import XCTest
import K2Core
@testable import K2Updater

final class PictureBackgroundChoiceTests: XCTestCase {
    private func image() throws -> PixelImage {
        try PixelImage(width: 240, height: 240, rgba: Data(repeating: 255, count: 240 * 240 * 4))
    }
    func testLegacyProjectsInferChoiceFromImageAndExplicitFalseSurvivesRoundTrip() throws {
        let blank = try PictureProject.decode(PictureProject().encoded())
        XCTAssertFalse(blank.usesBackground)
        let original = PictureProject(background: try image())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any])
        json.removeValue(forKey: "useBackground")
        let legacy = try PictureProject.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(legacy.usesBackground)
        var disabled = legacy
        disabled.useBackground = false
        let reopened = try PictureProject.decode(disabled.encoded())
        XCTAssertFalse(reopened.usesBackground)
        XCTAssertEqual(reopened.background, legacy.background)
    }
    @MainActor func testImportEnablesBackgroundAndChoiceSupportsUndoWithoutDeletingImage() throws {
        let store = PictureStore()
        XCTAssertFalse(store.project.usesBackground)
        let image = try image()
        store.applyImage(image, kind: .background)
        XCTAssertTrue(store.project.usesBackground)
        store.edit { $0.useBackground = false }
        XCTAssertFalse(store.project.usesBackground)
        XCTAssertEqual(store.project.background, image)
        store.undo()
        XCTAssertTrue(store.project.usesBackground)
        store.redo()
        XCTAssertFalse(store.project.usesBackground)
        let startup = try PixelImage(width: 235, height: 235, rgba: Data(repeating: 255, count: 235 * 235 * 4))
        store.applyImage(startup, kind: .startup)
        XCTAssertFalse(store.project.usesBackground)
    }
}
