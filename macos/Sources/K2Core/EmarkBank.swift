import Foundation

public struct EmarkBank: Equatable, Sendable {
    public static let size = 666
    public static let capacity = 10
    public private(set) var data: Data
    public init(data: Data) throws {
        let b = [UInt8](data)
        guard b.count == Self.size else { throw PictureError.invalid("E-Mark 配置集合长度必须是 666 字节") }
        if (b.prefix(4).allSatisfy { $0 == 0 } || b.prefix(4).allSatisfy { $0 == 255 }),
           b.dropFirst(4).allSatisfy({ $0 == 255 }) {
            throw PictureError.invalid("设备尚未保存自定义 E-Mark 配置。内置档位不在本次读取范围内。可导入 .wtemark 或点 + 新增配置，再备份并写入。")
        }
        let count = Int(b[5]), selected = Int(b[4])
        guard count <= Self.capacity, (count == 0 ? selected == 0 : selected < count) else { throw PictureError.invalid("配置数量或默认组无效") }
        for i in 0..<count { _ = try EmarkRecord(data: Data(b[(6 + i * 66)..<(72 + i * 66)])) }
        self.data = Data(b)
    }
    public var count: Int { Int(data[5]) }
    public var selected: Int { Int(data[4]) }
    public var records: [EmarkRecord] { (0..<count).map(record) }
    public func record(_ index: Int) -> EmarkRecord { precondition((0..<count).contains(index)); return try! EmarkRecord(data: data.subdata(in: (6 + index * 66)..<(72 + index * 66))) }
    public mutating func update(_ index: Int, record: EmarkRecord) throws {
        guard (0..<count).contains(index) else { throw PictureError.invalid("配置槽位无效") }
        data.replaceSubrange((6 + index * 66)..<(72 + index * 66), with: record.data)
    }
    public mutating func select(_ index: Int) throws {
        guard (0..<count).contains(index) else { throw PictureError.invalid("默认组无效") }; data[4] = UInt8(index)
    }
    public mutating func append(_ record: EmarkRecord) throws {
        guard count < Self.capacity else { throw PictureError.invalid("最多保存 10 组配置") }
        let p = 6 + count * 66; data.replaceSubrange(p..<(p + 66), with: record.data); data[5] += 1
    }
    public mutating func remove(_ index: Int) throws {
        guard (0..<count).contains(index) else { throw PictureError.invalid("配置槽位无效") }
        let oldCount = count, oldSelected = selected
        if index < oldCount - 1 { data.replaceSubrange((6 + index * 66)..<(6 + (oldCount - 1) * 66), with: data.subdata(in: (6 + (index + 1) * 66)..<(6 + oldCount * 66))) }
        // Do not discard the now inactive record; it is part of the original bytes.
        data[5] = UInt8(oldCount - 1)
        data[4] = UInt8(oldCount == 1 ? 0 : (oldSelected > index ? oldSelected - 1 : min(oldSelected, oldCount - 2)))
    }
    public mutating func move(_ index: Int, by delta: Int) throws {
        let target = index + delta
        guard (0..<count).contains(index), (0..<count).contains(target) else { throw PictureError.invalid("配置排序位置无效") }
        let a = record(index), b = record(target), chosen = selected
        try update(index, record: b); try update(target, record: a)
        if chosen == index { try select(target) } else if chosen == target { try select(index) }
    }
    public static var empty: EmarkBank {
        var b = Data(repeating: 255, count: size); b[4] = 0; b[5] = 0; return try! EmarkBank(data: b)
    }
    public func encoded(name: String? = nil) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(EmarkProject(schema: 1, type: "k2-emark-project", bank: data, name: name))
    }
    public static func projectName(in data: Data) throws -> String? {
        try JSONDecoder().decode(EmarkProject.self, from: data).name
    }
    public static func decode(_ data: Data) throws -> EmarkBank {
        guard data.count <= 65536 else { throw PictureError.invalid("E-Mark 工程过大") }
        let p = try JSONDecoder().decode(EmarkProject.self, from: data)
        guard p.schema == 1, p.type == "k2-emark-project" else { throw PictureError.invalid("E-Mark 工程版本不支持") }
        return try EmarkBank(data: p.bank)
    }
}

private struct EmarkProject: Codable { let schema: Int; let type: String; let bank: Data; let name: String? }
