import Cocoa

struct TrackedWindow {
    let windowID: CGWindowID
    let frame: CGRect
    let name: String?
}

class WindowTracker {
    static let shared = WindowTracker()

    private init() {}

    /// Get all visible windows for a given process ID
    func getWindows(forPID pid: pid_t) -> [TrackedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [TrackedWindow] = []

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }

            // Get window layer - only include normal windows (layer 0)
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }

            // Parse bounds
            guard let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            let cgFrame = CGRect(x: x, y: y, width: width, height: height)

            // Filter out tiny helper windows (< 50x50)
            guard cgFrame.width >= 50 && cgFrame.height >= 50 else {
                continue
            }

            let windowName = windowInfo[kCGWindowName as String] as? String
            let cocoaFrame = convertToCocoaCoordinates(cgFrame)

            windows.append(TrackedWindow(
                windowID: windowID,
                frame: cocoaFrame,
                name: windowName
            ))
        }

        return windows
    }

    /// Convert CGWindowList coordinates (top-left origin) to NSWindow coordinates (bottom-left origin)
    func convertToCocoaCoordinates(_ cgRect: CGRect) -> CGRect {
        // Get the primary screen (the one with the menu bar)
        guard let primaryScreen = NSScreen.screens.first else {
            return cgRect
        }

        let screenHeight = primaryScreen.frame.height

        // CGWindowList uses top-left origin, NSWindow uses bottom-left
        // Y coordinate needs to be flipped
        let cocoaY = screenHeight - cgRect.origin.y - cgRect.height

        return CGRect(
            x: cgRect.origin.x,
            y: cocoaY,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    /// Check if a specific window still exists
    func windowExists(_ windowID: CGWindowID) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        return windowList.contains { windowInfo in
            (windowInfo[kCGWindowNumber as String] as? CGWindowID) == windowID
        }
    }

    /// Get the current frame of a specific window
    func getWindowFrame(_ windowID: CGWindowID) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            guard let id = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  id == windowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            let cgFrame = CGRect(x: x, y: y, width: width, height: height)
            return convertToCocoaCoordinates(cgFrame)
        }

        return nil
    }
}
