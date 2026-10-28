import AppKit
import SwiftUI

extension BlockColor {
    var tint: Color { Color(nsColor: accentColor) }
    var background: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbRed: dark ? 32.0 / 255 : 1,
                           green: dark ? 33.0 / 255 : 1,
                           blue: dark ? 36.0 / 255 : 1, alpha: 1)
        })
    }
    var selectionMark: Color {
        switch self {
        case .yellow, .orange: Color(red: 0.06, green: 0.09, blue: 0.14)
        default: .white
        }
    }

    var accentColor: NSColor {
        let hex: UInt32
        switch self {
        case .gray: hex = 0x5F6368
        case .blue: hex = 0x1A73E8
        case .red: hex = 0xD93025
        case .yellow: hex = 0xF9AB00
        case .green: hex = 0x188038
        case .pink: hex = 0xD01884
        case .purple: hex = 0x9334E6
        case .teal: hex = 0x007B83
        case .orange: hex = 0xE8710A
        }
        return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                       green: CGFloat((hex >> 8) & 255) / 255,
                       blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
