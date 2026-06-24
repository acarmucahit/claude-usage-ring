import SwiftUI

public enum RingLevel: Sendable {
    case green, yellow, red

    public init(utilization: Double) {
        switch utilization {
        case ..<0.50: self = .green
        case ..<0.80: self = .yellow
        default:      self = .red
        }
    }

    public var color: Color {
        switch self {
        case .green:  return Color(red: 0.30, green: 0.78, blue: 0.45)
        case .yellow: return Color(red: 0.95, green: 0.77, blue: 0.20)
        case .red:    return Color(red: 0.92, green: 0.34, blue: 0.34)
        }
    }

    #if canImport(AppKit)
    public var nsColor: NSColor {
        switch self {
        case .green:  return NSColor(red: 0.30, green: 0.78, blue: 0.45, alpha: 1)
        case .yellow: return NSColor(red: 0.95, green: 0.77, blue: 0.20, alpha: 1)
        case .red:    return NSColor(red: 0.92, green: 0.34, blue: 0.34, alpha: 1)
        }
    }
    #endif
}
