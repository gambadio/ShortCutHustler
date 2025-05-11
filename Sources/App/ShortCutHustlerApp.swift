import SwiftUI

@main
struct ShortCutHustlerApp: App {
    @StateObject private var registry = ShortcutRegistry()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(registry)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}