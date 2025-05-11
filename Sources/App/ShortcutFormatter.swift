import Carbon.HIToolbox
import ApplicationServices

enum ShortcutFormatter {
    /// Turn keyCode + flags → "⌃⌥⌘ L"
    static func describe(keyCode: Int, flags: CGEventFlags) -> String {
        var s = ""
        if flags.contains(.maskControl)  { s += "⌃" } // Control
        if flags.contains(.maskAlternate){ s += "⌥" } // Option (Alt)
        if flags.contains(.maskShift)    { s += "⇧" } // Shift
        if flags.contains(.maskCommand)  { s += "⌘" } // Command

        // Only add space if there were modifiers and the key isn't empty or special
        let keyString = keyName(for: keyCode)
        if !s.isEmpty && !keyString.isEmpty && keyString != "␣" && keyString != "⏎" && keyString != "⎋" {
            // s += " " // Common convention is no space, e.g., ⌘C not ⌘ C
        }
        s += keyString
        return s
    }

    private static func keyName(for code: Int) -> String {
        // Standard US keyboard virtual key codes from Carbon HIToolbox/Events.h
        switch code {
        case kVK_Space:   return "␣" // Space symbol
        case kVK_Return:  return "⏎" // Return symbol
        case kVK_Delete:  return "⌫" // Delete symbol (Backspace on many keyboards)
        case kVK_ForwardDelete: return "⌦" // Forward Delete symbol
        case kVK_Escape:  return "⎋" // Escape symbol
        case kVK_Tab:     return "⇥" // Tab symbol
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:   return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_PageUp:    return "⇞"
        case kVK_PageDown:  return "⇟"
        case kVK_Home:      return "↖" // Or ⇱
        case kVK_End:       return "↘" // Or ⇲
        case kVK_F1: return "F1"; case kVK_F2: return "F2"; case kVK_F3: return "F3"
        case kVK_F4: return "F4"; case kVK_F5: return "F5"; case kVK_F6: return "F6"
        case kVK_F7: return "F7"; case kVK_F8: return "F8"; case kVK_F9: return "F9"
        case kVK_F10: return "F10"; case kVK_F11: return "F11"; case kVK_F12: return "F12"
        case kVK_F13: return "F13"; case kVK_F14: return "F14"; case kVK_F15: return "F15"
        case kVK_F16: return "F16"; case kVK_F17: return "F17"; case kVK_F18: return "F18"
        case kVK_F19: return "F19"; case kVK_F20: return "F20"
        // Add more kVK constants as needed for symbolic representation

        default:
            guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let raw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
            else { return "<\(code)>" } // Fallback with key code

            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
            return data.withUnsafeBytes { ptr in
                guard let layoutData = ptr.baseAddress else { return "<\(code)>" }
                var deadKeyState: UInt32 = 0
                var char: UniChar = 0
                var actualStringLength: Int = 0
                
                // Using 0 for modifierState as we only want the base character for the key code.
                // Modifiers (Cmd, Shift, etc.) are handled separately by the `describe` function.
                let err = UCKeyTranslate(layoutData.assumingMemoryBound(to: UCKeyboardLayout.self),
                                         UInt16(code),
                                         UInt16(kUCKeyActionDisplay), //kUCKeyActionDown produces string with modifiers
                                         0, // No modifiers for base key character
                                         UInt32(LMGetKbdType()),
                                         OptionBits(kUCKeyTranslateNoDeadKeysBit), // Or 0 to handle dead keys
                                         &deadKeyState,
                                         1, // Max char length
                                         &actualStringLength,
                                         &char)
                if err == noErr && actualStringLength == 1 {
                    return String(utf16CodeUnits: &char, count: 1).uppercased() // Often desired as uppercase
                } else {
                    return "<\(code)>" // Fallback if translation fails
                }
            }
        }
    }
}