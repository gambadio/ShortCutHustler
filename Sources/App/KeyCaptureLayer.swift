import SwiftUI

struct KeyCaptureLayer: NSViewRepresentable {
    var onCapture: (String) -> Void          // returns shortcut glyph string

    func makeNSView(context: Context) -> NSView {
        let v = Catcher(callback: onCapture)
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }
    func updateNSView(_: NSView, context: Context) {}

    final class Catcher: NSView {
        let callback: (String) -> Void
        init(callback: @escaping (String) -> Void) { self.callback = callback ; super.init(frame: .zero) }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with e: NSEvent) {
            guard !e.isARepeat else { return }
            callback( ShortcutFormatter.carbonStyle(char: e.charactersIgnoringModifiers ?? "",
                                                    modifiers: Int(e.modifierFlags.rawValue)) )
        }
    }
}