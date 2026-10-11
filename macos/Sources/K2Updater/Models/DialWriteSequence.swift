import K2Core

/// When background is enabled, a successful background write permits one layout
/// write to the same device. Layout-only writes skip this prerequisite.
/// DFU reconnection is enforced separately by UpdaterStore.canUseResources.
struct DialWriteSequence {
    private var backgroundDevice: String?

    func allows(_ kind: PictureResource, device: String, usesBackground: Bool = true) -> Bool {
        switch kind {
        case .background: return usesBackground
        case .layout: return !usesBackground || backgroundDevice == device
        default: return true
        }
    }

    mutating func started(_ kind: PictureResource) {
        // A failed replacement must not leave an earlier background authorization.
        if kind == .background { backgroundDevice = nil }
    }

    mutating func completed(_ kind: PictureResource, device: String, succeeded: Bool) {
        guard succeeded else { return }
        if kind == .background { backgroundDevice = device }
        else if kind == .layout { backgroundDevice = nil }
    }

    mutating func reset() { backgroundDevice = nil }
}
