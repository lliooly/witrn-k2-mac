import Foundation

public struct PictureProject: Codable, Equatable, Sendable {
    public var schema = 1
    public var name: String?
    public var layout: PictureLayout
    public var background: PixelImage?
    /// Optional for compatibility with projects saved before this choice existed.
    public var useBackground: Bool?
    public var usesBackground: Bool { useBackground ?? (background != nil) }
    public var startup: PixelImage?

    public init(name: String? = "我的 K2 工程", layout: PictureLayout = .standard, background: PixelImage? = nil, startup: PixelImage? = nil, useBackground: Bool? = nil) {
        self.name = name
        self.useBackground = useBackground
        self.layout = layout; self.background = background; self.startup = startup
    }

    public static func decode(_ data: Data) throws -> PictureProject {
        guard data.count <= 4_194_304 else { throw PictureError.invalid("表盘工程文件过大") }
        let project = try JSONDecoder().decode(Self.self, from: data)
        guard project.schema == 1 else { throw PictureError.invalid("不支持的表盘工程版本") }
        if let image = project.background { _ = try image.resourceData(.background) }
        if let image = project.startup { _ = try image.resourceData(.startup) }
        return project
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
