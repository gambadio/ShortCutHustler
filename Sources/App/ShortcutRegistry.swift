import AppKit
import ApplicationServices
import Combine

@MainActor
final class ShortcutRegistry: ObservableObject {
    @Published private(set) var rows: [ShortcutRow] = []
    @Published private(set) var frontmost: Bucket = .system

    private var cancellables = Set<AnyCancellable>()

    // MARK: ‑ init
    init() {
        collectSystemShortcuts()          // once
        watchFrontmostApp()               // keep in sync
    }

    // MARK: ‑ public helpers
    func isTaken(_ combo: String, scope: Bucket?) -> Bool {
        rows.contains { row in
            row.combo == combo && (scope == nil || row.bucket == scope!)
        }
    }

    // MARK: ‑ system shortcuts
    private func collectSystemShortcuts() {
        // clear existing system rows
        rows.removeAll { if case .system = $0.bucket { return true } ; return false }

        // 1. user‑defined “App Shortcuts” from System Settings
        if let globalDomain = UserDefaults.standard
                .persistentDomain(forName: "Apple Global Domain"),
           let dict = globalDomain["NSUserKeyEquivalents"] as? [String:String] {

            dict.values.forEach { key in
                rows.append(.init(combo: prettifyUserDefault(key), bucket: .system))
            }
        }

        // 2. hard‑coded Apple defaults (extend as you wish)
        ["⌘⇧3", "⌘⇧4", "⌃⌘Q", "⌘ Space"].forEach {
            rows.append(.init(combo: $0, bucket: .system))
        }
    }

    private func prettifyUserDefault(_ raw: String) -> String {
        // examples: "@~^f"  →  ⌘⌥⌃F      "@\u{7F}" (command‑delete)
        var out = ""
        if raw.contains("@") { out += "⌘" }
        if raw.contains("~") { out += "⌥" }
        if raw.contains("^") { out += "⌃" }
        if raw.contains("$") { out += "⇧" }
        let trimmed = raw.replacingOccurrences(of: "[@~^$]", with: "", options: .regularExpression)
        switch trimmed {
        case "\u{7F}": out += "⌫"
        default:       out += trimmed.uppercased()
        }
        return out
    }

    // MARK: ‑ per‑app shortcuts
    private func watchFrontmostApp() {
        NSWorkspace.shared.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink(receiveValue: { [weak self] app in
                Task { await self?.collectShortcuts(for: app) }
            })
            .store(in: &cancellables)
    }

    private func collectShortcuts(for app: NSRunningApplication) async {
        let bucket = Bucket.app(bundleID: app.bundleIdentifier ?? "-", name: app.localizedName ?? "App")

        // clear any rows that belonged to the previous frontmost app
        rows.removeAll {
            if case .app(let id, _) = $0.bucket { return id == app.bundleIdentifier }
            return false
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBar: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBar) == .success,
           let bar = menuBar {
            traverse(menuElement: bar, bucket: bucket)
        }
        frontmost = bucket
    }

    private func traverse(menuElement: AnyObject, bucket: Bucket) {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuElement as! AXUIElement,
                                            kAXChildrenAttribute as CFString,
                                            &children) == .success,
              let elements = children as? [AXUIElement] else { return }

        for el in elements {
            var charObj: AnyObject?
            if AXUIElementCopyAttributeValue(el, kAXMenuItemCmdCharAttribute as CFString, &charObj) == .success,
               let char = charObj as? String, !char.isEmpty {

                var modsObj: AnyObject?
                AXUIElementCopyAttributeValue(el, kAXMenuItemCmdModifiersAttribute as CFString, &modsObj)
                let mods = modsObj as? Int ?? 0
                let combo = ShortcutFormatter.carbonStyle(char: char, modifiers: mods)
                rows.append(.init(combo: combo, bucket: bucket))
            }
            traverse(menuElement: el, bucket: bucket)   // recursion
        }
    }
}