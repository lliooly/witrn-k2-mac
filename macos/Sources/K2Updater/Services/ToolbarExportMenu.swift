import AppKit
import SwiftUI

struct ToolbarExportMenuItem {
    let title: String
    var enabled = true
    let action: () -> Void
}

/// A native button occupies the entire glass capsule, including the arrow.
struct ToolbarExportMenu: NSViewRepresentable {
    let items: [ToolbarExportMenuItem]
    @Environment(\.isEnabled) private var enabled

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> ToolbarExportMenuButton {
        let button = ToolbarExportMenuButton(frame: .zero)
        button.title = ""
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.target = context.coordinator
        button.action = #selector(Coordinator.open(_:))
        button.toolTip = "导出"
        button.setAccessibilityLabel("导出")
        return button
    }
    func updateNSView(_ button: ToolbarExportMenuButton, context: Context) {
        context.coordinator.items = items
        button.isEnabled = enabled
    }

    final class Coordinator: NSObject {
        var items: [ToolbarExportMenuItem] = []
        @objc func open(_ sender: NSButton) {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for (index, item) in items.enumerated() {
                let entry = NSMenuItem(title: item.title, action: #selector(selectItem(_:)), keyEquivalent: "")
                entry.target = self
                entry.tag = index
                entry.isEnabled = item.enabled
                menu.addItem(entry)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 4), in: sender)
        }
        @objc func selectItem(_ sender: NSMenuItem) {
            guard items.indices.contains(sender.tag), items[sender.tag].enabled else { return }
            items[sender.tag].action()
        }
    }
}

final class ToolbarExportMenuButton: NSButton {
    // SwiftUI draws the symbols and glass; this view supplies native interaction.
    override func draw(_ dirtyRect: NSRect) {}
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
