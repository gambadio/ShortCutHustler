import SwiftUI
import ApplicationServices

struct KeyCaptureLayer: NSViewRepresentable {
    var onCapture: (Shortcut) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = Catcher(onCapture: onCapture)
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }
    func updateNSView(_: NSView, context _: Context) {}

    final class Catcher: NSView {
        let callback: (Shortcut) -> Void
        init(onCapture: @escaping (Shortcut) -> Void) {
            self.callback = onCapture
            super.init(frame: .zero)
        }
        @available(*, unavailable) required init?(coder _: NSCoder) {
            fatalError()
        }
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            // Skip if it's just a modifier key press without other keys
            if event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) && !event.charactersIgnoringModifiers!.isEmpty {
                 // This check might be too simple. Often, we want to capture modifier-only if that's the "shortcut"
            }

            // Let's only react to key down events that represent a character or a full shortcut
            // For now, the original simple version is fine as ShortcutFormatter handles modifiers + key.
            // We don't want to call back for *just* Shift, *just* Cmd, etc.
            // NSEvent's characters often returns nil for just modifier. The keyCode is what matters for ShortcutFormatter.
            // A more robust check for "is this a final key in a combo or just a modifier on its own?"
            // can be complex. The current approach of formatting any keyDown is standard for this type of tool.

            if !event.isARepeat { // Optional: ignore key repeats if desired
                callback(
                    ShortcutFormatter.describe(
                        keyCode: Int(event.keyCode),
                        flags: event.modifierFlags.cgEvent
                    )
                )
            }
        }
        // Optional: If you want to capture keyUp to reset state or for other logic
        // override func keyUp(with event: NSEvent) { /* ... */ }
    }
}