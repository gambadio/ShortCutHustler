import AppKit
import ApplicationServices

extension NSEvent.ModifierFlags {
    /// Bridge to CGEventFlags
    var cgEvent: CGEventFlags { CGEventFlags(rawValue: UInt64(self.rawValue)) }
}