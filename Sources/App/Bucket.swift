import Foundation

/// Where a shortcut lives.
enum Bucket: Hashable, Identifiable {
    case system                           // “Global (System)”
    case app(bundleID: String, name: String)

    var id: String {
        switch self {
        case .system:                           "system"
        case .app(let id, _):                   id
        }
    }
    var title: String {
        switch self {
        case .system:                           "Global (System)"
        case .app(_, let name):                 name
        }
    }
}

/// A single row in the UI table.
struct ShortcutRow: Identifiable, Hashable {
    let id = UUID()
    let combo: String      // e.g. "⌘⇧L"
    let bucket: Bucket
}