import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var focusManager: FocusManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        focusManager = FocusManager()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "💩"
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(focusManager: focusManager))

        checkAccessibilityPermissions()
        checkScreenRecordingPermission()
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("Accessibility permissions needed for Kaka to work properly")
        }
    }

    func checkScreenRecordingPermission() {
        if !hasScreenRecordingPermission() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showScreenRecordingPermissionAlert()
            }
        }
    }

    func hasScreenRecordingPermission() -> Bool {
        // Try to get window list - if we can get window names, we have permission
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Look for any window with a name - if we can read names, we have permission
        // Without permission, window names are nil or empty
        for windowInfo in windowList {
            if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
               !ownerName.isEmpty,
               let windowName = windowInfo[kCGWindowName as String] as? String,
               !windowName.isEmpty {
                return true
            }
        }

        // If we have windows but couldn't read any names, permission may be missing
        // We'll still return true if there are windows, since some apps don't set window names
        return windowList.count > 0
    }

    func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Kaka needs Screen Recording permission to detect window positions of other apps. This allows the overlay to cover only the distracting window instead of your entire screen.\n\nWithout this permission, Kaka will fall back to covering your entire screen when you get distracted."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
