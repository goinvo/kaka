import Cocoa
import Combine

struct RunningApp: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id
    }
}

class FocusManager: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var selectedApp: RunningApp?
    @Published var isFocusActive: Bool = false
    @Published var isDistracted: Bool = false

    private var overlayWindows: [CGWindowID: PoopOverlayWindow] = [:]
    private var fullScreenOverlays: [PoopOverlayWindow] = []
    private var workspaceObserver: NSObjectProtocol?
    private var timer: Timer?
    private var windowTrackingTimer: Timer?
    private var currentDistractingPID: pid_t?

    init() {
        loadRunningApps()
        setupWorkspaceObserver()
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        timer?.invalidate()
        windowTrackingTimer?.invalidate()
    }

    func loadRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications.filter { app in
            app.activationPolicy == .regular && app.localizedName != nil
        }

        runningApps = apps.compactMap { app in
            guard let name = app.localizedName else { return nil }
            return RunningApp(
                id: app.processIdentifier,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon
            )
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    func handleAppActivation(_ notification: Notification) {
        guard isFocusActive, let selectedApp = selectedApp else { return }

        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let activatedBundleId = activatedApp.bundleIdentifier
        let selectedBundleId = selectedApp.bundleIdentifier

        // Allow Kaka itself
        if activatedBundleId == Bundle.main.bundleIdentifier {
            return
        }

        // Check if user switched away from focus app
        if activatedBundleId != selectedBundleId {
            currentDistractingPID = activatedApp.processIdentifier
            showWindowOverlays(forPID: activatedApp.processIdentifier)
            isDistracted = true
        } else {
            hidePoopOverlays()
            isDistracted = false
        }
    }

    func startFocus() {
        guard selectedApp != nil else { return }
        isFocusActive = true
        isDistracted = false

        // Activate the selected app
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == selectedApp?.id }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    func stopFocus() {
        isFocusActive = false
        isDistracted = false
        hidePoopOverlays()
    }

    func showWindowOverlays(forPID pid: pid_t) {
        hidePoopOverlays()

        let windows = WindowTracker.shared.getWindows(forPID: pid)

        if windows.isEmpty {
            // Fall back to full-screen overlay if no windows found (likely permission issue)
            showFullScreenOverlays()
            return
        }

        // Create overlay for each window
        for trackedWindow in windows {
            let overlay = PoopOverlayWindow(frame: trackedWindow.frame, trackedWindowID: trackedWindow.windowID)
            overlay.show()
            overlayWindows[trackedWindow.windowID] = overlay
        }

        // Start window tracking timer
        startWindowTracking()
    }

    func showFullScreenOverlays() {
        for screen in NSScreen.screens {
            let overlay = PoopOverlayWindow(screen: screen)
            overlay.show()
            fullScreenOverlays.append(overlay)
        }
    }

    func hidePoopOverlays() {
        // Stop window tracking
        windowTrackingTimer?.invalidate()
        windowTrackingTimer = nil
        currentDistractingPID = nil

        // Hide window-specific overlays
        for (_, window) in overlayWindows {
            window.hide()
        }
        overlayWindows.removeAll()

        // Hide full-screen overlays
        for window in fullScreenOverlays {
            window.hide()
        }
        fullScreenOverlays.removeAll()
    }

    private func startWindowTracking() {
        windowTrackingTimer?.invalidate()

        windowTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateOverlayPositions()
        }
    }

    private func updateOverlayPositions() {
        guard let pid = currentDistractingPID else { return }

        let currentWindows = WindowTracker.shared.getWindows(forPID: pid)
        let currentWindowIDs = Set(currentWindows.map { $0.windowID })

        // Remove overlays for windows that no longer exist
        let staleWindowIDs = Set(overlayWindows.keys).subtracting(currentWindowIDs)
        for windowID in staleWindowIDs {
            overlayWindows[windowID]?.hide()
            overlayWindows.removeValue(forKey: windowID)
        }

        // Update positions for existing windows and add new ones
        for trackedWindow in currentWindows {
            if let existingOverlay = overlayWindows[trackedWindow.windowID] {
                // Update position if changed
                if existingOverlay.frame != trackedWindow.frame {
                    existingOverlay.updateFrame(trackedWindow.frame)
                }
            } else {
                // New window appeared - create overlay for it
                let overlay = PoopOverlayWindow(frame: trackedWindow.frame, trackedWindowID: trackedWindow.windowID)
                overlay.show()
                overlayWindows[trackedWindow.windowID] = overlay
            }
        }

        // If all windows closed, fall back to full screen
        if overlayWindows.isEmpty && fullScreenOverlays.isEmpty {
            showFullScreenOverlays()
        }
    }

    func returnToFocusApp() {
        guard let selectedApp = selectedApp else { return }

        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == selectedApp.id }) {
            app.activate(options: .activateIgnoringOtherApps)
        }

        hidePoopOverlays()
        isDistracted = false
    }
}
