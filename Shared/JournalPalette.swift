import SwiftUI

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch raw.count {
        case 8:
            red = (value >> 24) & 0xff
            green = (value >> 16) & 0xff
            blue = (value >> 8) & 0xff
            alpha = value & 0xff
        default:
            red = (value >> 16) & 0xff
            green = (value >> 8) & 0xff
            blue = value & 0xff
            alpha = 0xff
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

extension ShapeStyle where Self == Color {
    static var journalBackground: Color { Color(hex: "f5f2ec") }
    static var journalInk: Color { Color(hex: "3a3530") }
    static var journalBand: Color { Color(hex: "d5d0c8") }
    static var journalEnergy: Color { Color(hex: "8a9a72") }
    static var journalSleep: Color { Color(hex: "6b7f9e") }
    /// Trend colours for the adherence numbers, darkened from the mood palette so they hold
    /// contrast as large text on the paper background.
    static var journalTrendBetter: Color { Color(hex: "3f7d59") }
    static var journalTrendSteady: Color { Color(hex: "a07a12") }
    static var journalTrendWorse: Color { Color(hex: "b04a3c") }
}
