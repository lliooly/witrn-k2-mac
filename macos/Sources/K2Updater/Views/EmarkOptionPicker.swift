import AppKit
import SwiftUI

/// A native popup stretches its bezel to the same width as adjacent text fields.
struct EmarkOptionPicker: NSViewRepresentable {
    let title: String
    let options: [String]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let control = NSPopUpButton(frame: .zero, pullsDown: false)
        control.font = .systemFont(ofSize: NSFont.systemFontSize)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.target = context.coordinator
        control.action = #selector(Coordinator.selectOption(_:))
        return control
    }

    func updateNSView(_ control: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.options != options {
            control.removeAllItems()
            control.addItems(withTitles: options)
            context.coordinator.options = options
            context.coordinator.intrinsicSize = control.intrinsicContentSize
        }
        if control.indexOfSelectedItem != selection { control.selectItem(at: selection) }
        if control.isEnabled != context.environment.isEnabled { control.isEnabled = context.environment.isEnabled }
        if context.coordinator.title != title {
            control.setAccessibilityLabel(title)
            context.coordinator.title = title
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let intrinsic = context.coordinator.intrinsicSize ?? nsView.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsic.width, height: intrinsic.height)
    }

    final class Coordinator: NSObject {
        var parent: EmarkOptionPicker
        var options: [String] = []
        var title: String?
        var intrinsicSize: CGSize?
        init(_ parent: EmarkOptionPicker) { self.parent = parent }
        @objc func selectOption(_ sender: NSPopUpButton) {
            parent.selection = sender.indexOfSelectedItem
        }
    }
}
