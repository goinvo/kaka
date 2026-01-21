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

    private var overlayWindows: [PoopOverlayWindow] = []
    private var workspaceObserver: NSObjectProtocol?
    private var timer: Timer?

    init() {
        loadRunningApps()
        setupWorkspaceObserver()
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        timer?.invalidate()
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
            showPoopOverlays()
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

    func showPoopOverlays() {
        hidePoopOverlays()

        // Get all screens
        for screen in NSScreen.screens {
            let overlay = PoopOverlayWindow(screen: screen)
            overlay.show()
            overlayWindows.append(overlay)
        }
    }

    func hidePoopOverlays() {
        for window in overlayWindows {
            window.hide()
        }
        overlayWindows.removeAll()
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
