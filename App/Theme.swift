//
//  Theme.swift
//  Money lessons with Penny the Pangolin — interactive SwiftUI mock-up.
//
//  Central place for the brand palette and a few shared style helpers, so every
//  screen stays consistent. Colours come straight from README.md section 2.
//
//  NOTE: The app has no public name yet (held pending a trademark search).
//  Where a name string is unavoidable we use the placeholder "MoneyPals".
//

import SwiftUI

/// Brand palette. Copper / teal / peach — deliberately NOT green-led, so the
/// app never reads as a Duolingo clone (see README.md section 2).
enum Palette {
    // Core brand colours (README section 2 "Colors").
    static let copper   = Color(hex: 0xC9793A) // Penny's body
    static let teal     = Color(hex: 0x1F6F78) // scarf + main buttons
    static let peach    = Color(hex: 0xFFD9B8) // face / belly / warm backdrops
    static let skyTeal  = Color(hex: 0x6CC4C9) // highlights

    // Answer-feedback glows (README section 3). Soft, never a solid banner,
    // and the wrong-answer colour is warm apricot — never red.
    static let rightGlow = Color(hex: 0x9BE7A8) // soft mint green
    static let wrongGlow = Color(hex: 0xFFC58A) // warm apricot

    // Neutral supports.
    static let ink      = Color(hex: 0x2C2622) // warm near-black text
    static let cream    = Color(hex: 0xFFF6EC) // page background
    static let lockGrey = Color(hex: 0xC9C1B8) // locked level tint

    /// Six kid-avatar colour choices (README section 6 "outfit color (6)").
    static let avatarChoices: [Color] = [
        Color(hex: 0x1F6F78), // teal
        Color(hex: 0xC9793A), // copper
        Color(hex: 0x6CC4C9), // sky teal
        Color(hex: 0xE5714E), // coral
        Color(hex: 0x8E6BB0), // grape
        Color(hex: 0x4C9F70)  // leaf
    ]
}

extension Color {
    /// Build a Color from a 24-bit hex literal, e.g. `Color(hex: 0x1F6F78)`.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Shared button style

/// Big, rounded, kid-friendly primary button. Large tap target, clear label.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Palette.teal
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            // Gentle press feedback; harmless when Reduce Motion is on (no bounce).
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    /// Standard cream page background used across the kid-facing screens.
    func kidPageBackground() -> some View {
        self.background(Palette.cream.ignoresSafeArea())
    }
}
