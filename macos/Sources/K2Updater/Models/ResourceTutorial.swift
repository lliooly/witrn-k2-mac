import Foundation
import K2Core

enum ResourceTutorialKind: String, CaseIterable, Identifiable {
    case dial, startup, emark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dial: return "表盘写入教程"
        case .startup: return "开机图写入教程"
        case .emark: return "虚拟 E-Mark 教程"
        }
    }
    var readingSeconds: TimeInterval { self == .emark ? 0 : (self == .dial ? 5 : 3) }
    static let sourceURL = URL(string: "https://github.com/JohnScotttt/WITRN-K2-Quick-Reference-Manual#51-怎么自定义表盘和开机图")!
    var referenceURL: URL {
        self == .emark
            ? URL(string: "https://github.com/JohnScotttt/WITRN-K2-Quick-Reference-Manual#6-E-Marker类")!
            : Self.sourceURL
    }
    static func forResource(_ resource: PictureResource) -> Self? {
        switch resource {
        case .layout, .background: return .dial
        case .startup: return .startup
        default: return nil
        }
    }
}

/// Session-only acknowledgements. Only the first confirmed reading requires a
/// monotonic countdown; cancelling or merely waiting never accepts a tutorial.
struct ResourceTutorialGate {
    private(set) var presented: ResourceTutorialKind?
    private(set) var accepted: Set<ResourceTutorialKind> = []
    private var openedAt: TimeInterval?

    mutating func open(_ kind: ResourceTutorialKind, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        presented = kind
        openedAt = now
    }
    func remaining(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int {
        guard let presented, let openedAt else { return 0 }
        guard !accepted.contains(presented) else { return 0 }
        return Int(ceil(max(0, presented.readingSeconds - max(0, now - openedAt))))
    }
    mutating func confirm(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard let presented, remaining(now: now) == 0 else { return false }
        accepted.insert(presented)
        cancel()
        return true
    }
    mutating func cancel() { presented = nil; openedAt = nil }
    func allows(_ resource: PictureResource) -> Bool {
        ResourceTutorialKind.forResource(resource).map { accepted.contains($0) } ?? true
    }
}
