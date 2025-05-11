import AppKit
import ApplicationServices

extension NSEvent.ModifierFlags {
    var carbon: Int { Int(rawValue) & 0xFFFF }   // convenience if you need it
}