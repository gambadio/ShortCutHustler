import AppKit
import ApplicationServices
import Combine

typealias Shortcut = String  // e.g. "⌃⌥⌘ L"

enum Bucket: Hashable {
    case global
    case app(NSRunningApplication)

    var title: String {
        switch self {
        case .global:      return "Global (System)"
        case .app(let a):  return a.localizedName ?? "Unknown App"
        }
    }
    var pid: pid_t {
        switch self {
        case .global:      return 0
        case .app(let a):  return a.processIdentifier
        }
    }
}

struct ShortcutRow: Identifiable {
    let id = UUID()
    let shortcut: Shortcut
    let bucket: Bucket
}

@MainActor
final class ShortcutRegistry: ObservableObject {
    @Published var rows: [ShortcutRow] = []
    @Published var frontmost: Bucket =
        .app(NSWorkspace.shared.frontmostApplication ?? NSRunningApplication()) // NSRunningApplication() defaults to current app if frontmost is nil
    @Published var inputMonitoringPermissionGranted: Bool = true // Assume true until tap creation fails

    private var tap: CFMachPort?
    private var src: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Use NotificationCenter directly to avoid ambiguity
        NotificationCenter.default
            .publisher(for: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared)
            .compactMap { notification in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] app in
                self?.frontmost = .app(app)
            }
            .store(in: &cancellables)
    }

    func start() {
        guard tap == nil else { return }

        // Attempt to create the event tap
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard type == .keyDown else { return Unmanaged.passUnretained(event) }

                let pid = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
                let flags = event.flags
                let code  = Int(event.getIntegerValueField(.keyboardEventKeycode))
                let shortcut = ShortcutFormatter.describe(keyCode: code, flags: flags)

                Task { @MainActor in
                    guard let refcon = refcon else { return }
                    let reg = Unmanaged<ShortcutRegistry>.fromOpaque(refcon).takeUnretainedValue()
                    
                    let bucket: Bucket
                    if pid == 0 {
                        bucket = .global
                    } else {
                        if let appInstance = NSRunningApplication(processIdentifier: pid) {
                            bucket = .app(appInstance)
                        } else {
                            // Could not get NSRunningApplication instance for this PID.
                            // Log this occurrence but don't add to rows, to prevent crash and keep registry clean.
                            print("Warning: Could not identify application with PID \(pid) for shortcut '\(shortcut)'. This shortcut event will not be added for this PID.")
                            return // Exit Task for this event processing
                        }
                    }

                    if !reg.rows.contains(where: { $0.shortcut == shortcut && $0.bucket.pid == bucket.pid }) {
                        reg.rows.append(ShortcutRow(shortcut: shortcut, bucket: bucket))
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        if newTap == nil {
            print("Unable to create event tap; check Input Monitoring permissions.")
            // Update permission status on the main thread for UI reaction
            DispatchQueue.main.async {
                self.inputMonitoringPermissionGranted = false
            }
            return // Exit start() if tap creation failed
        }
        
        // Tap creation succeeded
        self.tap = newTap
        DispatchQueue.main.async {
            self.inputMonitoringPermissionGranted = true
        }

        src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.tap!, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src!, .commonModes)
        CGEvent.tapEnable(tap: self.tap!, enable: true)
    }

    func stop() {
        if let s = src { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, .commonModes) }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        src = nil; tap = nil
    }

    func isTaken(_ shortcut: Shortcut, scope: Bucket?) -> Bool {
        if let s = scope {
            return rows.contains { $0.shortcut == shortcut && $0.bucket.pid == s.pid }
        } else { // "All" scope
            return rows.contains { $0.shortcut == shortcut }
        }
    }
}