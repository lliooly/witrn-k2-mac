import SwiftUI

/// Changes columns without replacing controls. Reuses measurements between
/// SwiftUI's size proposals and placement pass at the same width.
struct EmarkGridLayout: Layout {
    let columnBreakpoint: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat

    struct Cache {
        var width: CGFloat?
        var frames: [CGRect] = []
        var size = CGSize.zero
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Text validation, selection and expanded content can change heights.
        cache = Cache()
    }

    private func measure(width: CGFloat, subviews: Subviews, cache: inout Cache) {
        guard cache.width != width else { return }
        let columns = width >= columnBreakpoint ? 2 : 1
        let cardWidth = max(0, (width - CGFloat(columns - 1) * columnSpacing) / CGFloat(columns))
        var y: CGFloat = 0
        cache.frames.removeAll(keepingCapacity: true)
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let end = min(start + columns, subviews.count)
            var rowHeight: CGFloat = 0
            for index in start..<end {
                rowHeight = max(rowHeight, subviews[index].sizeThatFits(
                    ProposedViewSize(width: cardWidth, height: nil)
                ).height)
            }
            for index in start..<end {
                cache.frames.append(CGRect(x: CGFloat(index - start) * (cardWidth + columnSpacing), y: y,
                                           width: cardWidth, height: rowHeight))
            }
            y += rowHeight + rowSpacing
        }
        cache.width = width
        cache.size = CGSize(width: width, height: max(0, y - rowSpacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 700
        measure(width: max(0, width), subviews: subviews, cache: &cache)
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        measure(width: bounds.width, subviews: subviews, cache: &cache)
        for (subview, frame) in zip(subviews, cache.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}
