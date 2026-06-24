#if canImport(AppKit)
import AppKit

/// Renders the two stacked menu-bar mini-bars as a colored NSImage.
/// The menu bar does not reliably render SwiftUI `Canvas`/`Shape` content in a
/// label, so we draw an explicit (non-template) image instead.
/// Top bar = 5-hour window, bottom bar = weekly window.
public enum MiniBarsRenderer {
    public static func image(weekly: Double, fiveHour: Double, enabled: Bool) -> NSImage {
        let size = NSSize(width: 26, height: 15)
        let image = NSImage(size: size, flipped: false) { _ in
            let barH: CGFloat = 4.0
            let gap: CGFloat = 3.0
            let bottom = (size.height - (barH * 2 + gap)) / 2
            // Bottom bar = weekly, top bar = five-hour.
            drawBar(y: bottom, width: size.width, height: barH,
                    fraction: weekly, color: barColor(weekly, enabled: enabled))
            drawBar(y: bottom + barH + gap, width: size.width, height: barH,
                    fraction: fiveHour, color: barColor(fiveHour, enabled: enabled))
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func barColor(_ fraction: Double, enabled: Bool) -> NSColor {
        enabled ? RingLevel(utilization: fraction).nsColor : NSColor(white: 0.6, alpha: 1)
    }

    private static func drawBar(y: CGFloat, width: CGFloat, height: CGFloat,
                                fraction: Double, color: NSColor) {
        let radius = height / 2
        // Always-visible track.
        let track = NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: width, height: height),
                                 xRadius: radius, yRadius: radius)
        NSColor(white: 0.55, alpha: 0.5).setFill()
        track.fill()

        let w = width * RingGeometry.trimEnd(for: fraction)
        guard w > 0 else { return }
        let fill = NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: max(height, w), height: height),
                                xRadius: radius, yRadius: radius)
        color.setFill()
        fill.fill()
    }
}
#endif
