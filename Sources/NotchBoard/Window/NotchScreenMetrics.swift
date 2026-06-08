import AppKit

/// Resolves the geometry of the notch (or a sensible fallback area) for a given screen.
struct NotchScreenMetrics {
    /// Width of the physical notch in points. Falls back to a virtual notch width.
    let notchWidth: CGFloat
    /// Height of the menu bar / notch area in points.
    let notchHeight: CGFloat
    /// Whether the screen has a real hardware notch.
    let hasHardwareNotch: Bool
    /// The screen these metrics were computed for.
    let screen: NSScreen

    /// Fallback width used on Macs without a hardware notch.
    static let virtualNotchWidth: CGFloat = 220

    init(screen: NSScreen) {
        self.screen = screen

        let topInset = screen.safeAreaInsets.top
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height
            - (screen.visibleFrame.origin.y - screen.frame.origin.y)

        if topInset > 0 {
            // Hardware notch present. auxiliaryTopLeftArea / auxiliaryTopRightArea
            // bracket the notch; the gap between them is the notch width.
            self.hasHardwareNotch = true
            self.notchHeight = topInset

            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                self.notchWidth = max(right.minX - left.maxX, 120)
            } else {
                self.notchWidth = Self.virtualNotchWidth
            }
        } else {
            self.hasHardwareNotch = false
            self.notchHeight = max(menuBarHeight, 24)
            self.notchWidth = Self.virtualNotchWidth
        }
    }

    /// The screen that currently hosts the menu bar / notch (the main screen).
    static var primary: NotchScreenMetrics {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        return NotchScreenMetrics(screen: screen)
    }

    /// Centered frame (in screen coordinates) for the closed notch pill.
    func closedFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let f = screen.frame
        let x = f.midX - width / 2
        let y = f.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
