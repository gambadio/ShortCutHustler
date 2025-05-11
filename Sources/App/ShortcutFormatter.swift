import Carbon.HIToolbox
import ApplicationServices
import AppKit

enum ShortcutFormatter {

    /// From Carbon modifier bit‑field + char → glyph string (⌃⌥⌘ F).
    static func carbonStyle(char: String, modifiers: Int) -> String {
        var out = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if flags.contains(.control)  { out += "⌃" }
        if flags.contains(.option)   { out += "⌥" }
        if flags.contains(.shift)    { out += "⇧" }
        if flags.contains(.command)  { out += "⌘" }
        out += char.uppercased()
        return out
    }
}