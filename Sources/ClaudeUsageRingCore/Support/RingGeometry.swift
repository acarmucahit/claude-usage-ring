import Foundation

public enum RingGeometry {
    /// Clamps a 0...1 fraction for use as a bar/arc fill length.
    public static func trimEnd(for fraction: Double) -> Double {
        min(1.0, max(0.0, fraction))
    }
}
