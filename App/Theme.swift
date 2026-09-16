//
//  Theme.swift
//  Money lessons with Penny the Pangolin — interactive SwiftUI mock-up.
//
//  The shared design system: brand palette, a rounded kid-legible type scale,
//  spacing / radius / shadow tokens, warm gradient backgrounds, per-"world"
//  tints for the map, and the primary / secondary button styles. Everything is
//  built from Penny's colours (README.md section 2) so every screen reads as one
//  designed, premium, kid-friendly whole rather than a template.
//
//  NOTE: The app has no public name yet (held pending a trademark search).
//  Where a name string is unavoidable we use the placeholder "MoneyPals".
//

import SwiftUI

// MARK: - Palette

/// Brand palette. Copper / teal / peach — deliberately NOT green-led, so the
/// app never reads as a Duolingo clone (see README.md section 2). Each core
/// colour carries light/dark companions so shapes can be shaded for the
/// "glossy movie look" without importing art.
enum Palette {
    // Core brand colours (README section 2 "Colors").
    static let copper   = Color(hex: 0xC9793A) // Penny's body
    static let teal     = Color(hex: 0x1F6F78) // scarf + main buttons
    static let peach    = Color(hex: 0xFFD9B8) // face / belly / warm backdrops
    static let skyTeal  = Color(hex: 0x6CC4C9) // highlights

    // Shading companions — used for gradients / glossy highlights on Penny,
    // buttons and cards. Kept close in hue so the palette stays cohesive.
    static let copperLight = Color(hex: 0xE8A56B)
    static let copperDeep  = Color(hex: 0xA85E28)
    static let tealLight   = Color(hex: 0x2E8A93)
    static let tealDeep    = Color(hex: 0x155158)
    static let peachDeep   = Color(hex: 0xF7C9A0)
    static let gold        = Color(hex: 0xF4C24B) // coins / stars

    // Answer-feedback glows (README section 3). Soft, never a solid banner,
    // and the wrong-answer colour is warm apricot — never red.
    static let rightGlow = Color(hex: 0x9BE7A8) // soft mint green
    static let wrongGlow = Color(hex: 0xFFC58A) // warm apricot
    static let rightInk  = Color(hex: 0x2E8B57) // deep green for the right badge

    // Neutral supports.
    static let ink      = Color(hex: 0x2C2622) // warm near-black text
    static let cream    = Color(hex: 0xFFF6EC) // page background
    static let creamDeep = Color(hex: 0xFCE9D4) // lower half of the warm backdrop
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

    /// A gentle two-stop tint for each of the four map "worlds" (README §5), so
    /// each stretch of the path feels like its own place. Order matches
    /// `SampleData.worlds`.
    static func worldTint(_ world: String) -> (Color, Color) {
        switch world {
        case "Money Basics":    return (teal, skyTeal)
        case "Save & Spend":    return (copper, Color(hex: 0xE5714E))
        case "Money Helpers":   return (Color(hex: 0x8E6BB0), skyTeal)
        case "Big Money Ideas": return (Color(hex: 0x4C9F70), gold)
        default:                return (teal, skyTeal)
        }
    }
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

// MARK: - Type scale (rounded, Dynamic-Type friendly)

/// A friendly, rounded type scale. Every size is anchored to a system text
/// style so it still scales with Dynamic Type, and uses `.rounded` so the whole
/// app speaks in one soft, kid-legible voice.
extension Font {
    static let kidHero      = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let kidTitle     = Font.system(.title, design: .rounded).weight(.bold)
    static let kidTitle2    = Font.system(.title2, design: .rounded).weight(.bold)
    static let kidHeadline  = Font.system(.title3, design: .rounded).weight(.bold)
    static let kidBody      = Font.system(.body, design: .rounded).weight(.medium)
    static let kidCallout   = Font.system(.callout, design: .rounded).weight(.semibold)
    static let kidCaption   = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let kidFootnote  = Font.system(.footnote, design: .rounded)
}

// MARK: - Spacing / radius / shadow tokens

/// A small, consistent spacing rhythm so screens breathe the same way.
enum Metric {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    static let cardRadius: CGFloat = 26
    static let buttonRadius: CGFloat = 24
    static let chipRadius: CGFloat = 18
    static let pagePadding: CGFloat = 24
}

/// Soft, warm shadow used on cards and floating elements — never a hard grey
/// drop, always a gentle copper-tinted lift.
struct SoftShadow: ViewModifier {
    var strong = false
    func body(content: Content) -> some View {
        content
            .shadow(color: Palette.copperDeep.opacity(strong ? 0.18 : 0.10),
                    radius: strong ? 18 : 12, x: 0, y: strong ? 10 : 6)
    }
}

extension View {
    func softShadow(strong: Bool = false) -> some View {
        modifier(SoftShadow(strong: strong))
    }
}

// MARK: - Backgrounds

/// The standard warm backdrop for kid-facing screens: a soft top-to-bottom
/// cream→peach wash with two very light corner glows, so the page has depth
/// without competing with the content.
struct WarmBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.cream, Palette.creamDeep],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Palette.skyTeal.opacity(0.16), .clear],
                center: .topLeading, startRadius: 10, endRadius: 380
            )
            RadialGradient(
                colors: [Palette.peach.opacity(0.5), .clear],
                center: .bottomTrailing, startRadius: 10, endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Standard warm gradient page background used across the kid-facing screens.
    func kidPageBackground() -> some View {
        self.background(WarmBackground())
    }
}

// MARK: - Card surface

/// A soft, slightly-raised white card. The single card look used everywhere so
/// surfaces feel like one material.
struct CardSurface: ViewModifier {
    var radius: CGFloat = Metric.cardRadius
    var strong = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    )
            )
            .softShadow(strong: strong)
    }
}

extension View {
    func cardSurface(radius: CGFloat = Metric.cardRadius, strong: Bool = false) -> some View {
        modifier(CardSurface(radius: radius, strong: strong))
    }
}

// MARK: - Button styles

/// Big, rounded, kid-friendly primary button. A glossy gradient fill with a
/// soft lift and a satisfying spring press (squash + settle). Reduce Motion is
/// honoured automatically — the press just dims, without the spring.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Palette.teal
    var textColor: Color = .white
    var icon: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return HStack(spacing: 10) {
            if let icon { Image(systemName: icon).font(.headline.weight(.bold)) }
            configuration.label
        }
        .font(.kidHeadline)
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [fill.lighter(0.10), fill.darker(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // Top glossy sheen.
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .padding(1)
                )
        )
        .softShadow(strong: false)
        .opacity(isEnabled ? (pressed ? 0.94 : 1) : 0.5)
        .scaleEffect(reduceMotion ? 1 : (pressed ? 0.96 : 1))
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.55),
                   value: pressed)
    }
}

/// A quieter secondary action: tinted, outlined, still springy.
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Palette.teal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.kidHeadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                            .stroke(tint.opacity(0.35), lineWidth: 2)
                    )
            )
            .opacity(pressed ? 0.85 : 1)
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.6),
                       value: pressed)
    }
}

// MARK: - Colour helpers

extension Color {
    /// Blend toward white by `amount` (0…1) for glossy highlights.
    func lighter(_ amount: Double) -> Color { blended(with: .white, amount: amount) }
    /// Blend toward black by `amount` (0…1) for shading.
    func darker(_ amount: Double) -> Color { blended(with: .black, amount: amount) }

    private func blended(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let a = max(0, min(1, amount))
        let c1 = UIColor(self)
        let c2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * a),
                     green: Double(g1 + (g2 - g1) * a),
                     blue: Double(b1 + (b2 - b1) * a),
                     opacity: Double(a1 + (a2 - a1) * a))
        #else
        // Non-UIKit SDKs are only used for a macOS type-check; the app ships on
        // iOS where the branch above runs. Return the base colour unchanged.
        return self
        #endif
    }
}
