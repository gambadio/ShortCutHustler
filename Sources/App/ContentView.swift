import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var reg: ShortcutRegistry
    @State private var selectedScope: Bucket? = nil          // nil = All
    @State private var capture = false
    @State private var candidate = ""

    @State private var sort: [KeyPathComparator<ShortcutRow>] = [
        .init(\.combo, order: .forward)
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedScope) {
                Text("All Shortcuts").tag(Bucket?.none)
                Text("Global (System)").tag(Bucket?.some(.system))
                Text(reg.frontmost.title).tag(Bucket?.some(reg.frontmost))
            }
            .frame(minWidth: 180)
        } detail: {
            VStack(spacing: 0) {
                Table(filteredRows, sortOrder: $sort) {
                    TableColumn("Shortcut", value: \.combo) { Text($0.combo) }
                    TableColumn("Where")   { Text($0.bucket.title) }
                }
                .tableStyle(.inset)
                .font(.system(.body, design: .monospaced))

                Divider()

                tester
            }
            .padding(.top, 6)
        }
    }

    private var filteredRows: [ShortcutRow] {
        let base = selectedScope == nil
            ? reg.rows
            : reg.rows.filter { $0.bucket == selectedScope! }
        return base.sorted(using: sort)
    }

    private var tester: some View {
        HStack {
            Button(capture ? "Press now…" : "Try a Shortcut") { capture.toggle() }
                .keyboardShortcut(.defaultAction)
                .foregroundColor(capture ? .orange : nil)

            Text(candidate.isEmpty ? "—" : candidate)
                .frame(minWidth: 100, alignment: .leading)
                .font(.system(.body, design: .monospaced))

            if !candidate.isEmpty {
                Circle()
                    .fill(reg.isTaken(candidate, scope: selectedScope) ? Color.red : Color.green)
                    .frame(width: 14, height: 14)
                Text(reg.isTaken(candidate, scope: selectedScope) ? "USED" : "FREE")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            capture ? KeyCaptureLayer { combo in
                candidate = combo
                capture = false
            } : nil
        )
    }
}