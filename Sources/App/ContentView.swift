import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var reg: ShortcutRegistry
    @State private var selectedScope: Bucket? = nil  // nil = “All”
    @State private var captureNext = false
    @State private var candidate: Shortcut = ""

    // 1. Add state for sort order
    @State private var sortOrder: [KeyPathComparator<ShortcutRow>] = [
        .init(\.shortcut, order: .forward) // Default sort by shortcut, ascending
    ]

    var body: some View {
        if reg.inputMonitoringPermissionGranted {
            mainContentView
                .frame(minWidth: 640, minHeight: 420)
                .onReceive(reg.$frontmost) { newFrontmostBucket in
                    // If selectedScope is not nil (i.e., not "All") AND not .global,
                    // it means an app-specific scope (either the "Frontmost App"
                    // or a previously frontmost app) was selected.
                    // In this case, we want it to track the newFrontmostBucket.
                    if selectedScope != nil && selectedScope != .some(.global) {
                        // This ensures that if "Frontmost App" was selected, it updates.
                        // If "Global" or "All" was selected, they remain unchanged.
                        selectedScope = .some(newFrontmostBucket)
                    }
                }
        } else {
            permissionRequestView
                .frame(minWidth: 640, minHeight: 420)
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            scopePicker
            shortcutTable
            Divider()
            tester
        }
    }

    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Text("Input Monitoring Permission Required")
                .font(.title2)
            Text("ShortCutHustler needs permission to monitor keyboard input to discover shortcuts. This allows it to list global and application-specific keyboard shortcuts as you type them.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Please go to System Settings > Privacy & Security > Input Monitoring, and enable ShortCutHustler.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Input Monitoring Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") {
                    NSWorkspace.shared.open(url)
                } else {
                    // Fallback if the specific path doesn't open, open general Privacy & Security
                    if let generalUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                         NSWorkspace.shared.open(generalUrl)
                    }
                }
            }
            Button("Retry / Check Again") {
                // This will re-attempt to start the registry, which re-checks permissions.
                // If permissions were just granted, this should make the app work.
                reg.start()
            }
        }
        .padding()
    }

    private var scopePicker: some View {
        HStack(spacing: 8) {
            Text("Scope:")
            Picker("Scope", selection: $selectedScope.animation()) {
                Text("All").tag(Bucket?.none)
                Text(Bucket.global.title).tag(Bucket?.some(.global))
                // Ensure reg.frontmost is a valid Bucket instance for the tag
                Text(reg.frontmost.title).tag(Bucket?.some(reg.frontmost))
            }
            .pickerStyle(.segmented)
            Spacer()
        }
        .padding([.top, .horizontal], 10)
        .padding(.bottom, 5)
    }

    private var shortcutTable: some View {
        // 2. Pass the sortOrder binding to the Table
        Table(filteredRows, sortOrder: $sortOrder) {
            // Ensure properties used in KeyPath (\.shortcut, \.bucket.title) are Comparable
            TableColumn("Shortcut", value: \.shortcut) { row in
                Text(row.shortcut)
            }
            // For \.bucket.title, we need to make sure sorting by it is intended
            // and Bucket.title (String) is directly comparable.
            // If Bucket itself should be comparable, it needs to conform to Comparable.
            // Here, we assume we are sorting by the String title.
            TableColumn("Where", value: \.bucket.title) { row in
                Text(row.bucket.title)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(.body, design: .monospaced))
        // No .onChange needed here for sortOrder if filteredRows handles it directly
    }

    private var tester: some View {
        HStack(spacing: 12) {
            Button(captureNext ? "Press shortcut now…" : "Try a Shortcut") {
                captureNext.toggle()
                if !captureNext { // If toggling off, clear candidate
                    candidate = ""
                }
            }
            .keyboardShortcut(.defaultAction) // Allows Enter key to trigger button
            .foregroundColor(captureNext ? Color.orange : nil)

            Text(candidate.isEmpty ? "—" : candidate)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 100, alignment: .leading)

            if !candidate.isEmpty {
                Circle()
                    .fill(reg.isTaken(candidate, scope: selectedScope) ? Color.red : Color.green)
                    .frame(width: 14, height: 14)

                Text(reg.isTaken(candidate, scope: selectedScope) ? "USED" : "FREE")
                    .foregroundColor(.secondary)
                    .font(.body)
            } else {
                Circle().fill(Color.clear).frame(width: 14, height: 14)
                Text(" ").foregroundColor(.secondary).font(.body)
            }
            Spacer()
        }
        .padding(10)
        .background(
            Group {
                if captureNext {
                    KeyCaptureLayer { sc in
                        candidate = sc
                        captureNext = false
                    }
                } else {
                    EmptyView()
                }
            }
        )
    }

    // 3. Modify filteredRows to use the sortOrder state
    private var filteredRows: [ShortcutRow] {
        let baseRows: [ShortcutRow]
        if let scope = selectedScope {
            baseRows = reg.rows.filter { $0.bucket.pid == scope.pid }
        } else {
            baseRows = reg.rows // "All" scope
        }

        // Apply sorting based on the current sortOrder
        // The `sorted(using:)` method is available if ShortcutRow properties are Comparable
        // and KeyPathComparators are correctly defined.
        // String (for shortcut and bucket.title) is Comparable.
        return baseRows.sorted(using: sortOrder)
    }
}
