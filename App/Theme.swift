//
//  Theme.swift
//  Design tokens for the SwiftUI mock-up, transcribed LITERALLY from the
//  Penny Design System (tokens/*.css). Colours, type scale, spacing, radii,
//  borders, the single shadow, and motion timings all live here so every screen
//  stays true to the system.
//
//  NOTE: The app has no public name yet (held pending a trademark search).
//  Where a name string is unavoidable we use the placeholder "MoneyPals".
//

import SwiftUI

// MARK: - Palette (tokens/colors.css)

/// Brand palette. Copper / teal / peach — deliberately NOT green-led, so the
/// app never reads as a Duolingo clone. Green never leads; the streak icon is a
/// coin, never a flame; and there is no red anywhere in the system.
enum Palette {
    // Core brand.
    static let copper   = Color(hex: 0xC9793A) // Penny's body
    static let teal     = Color(hex: 0x1F6F78) // scarf + every primary button + headings
    static let peach    = Color(hex: 0xFFD9B8) // face / belly / warm backdrop band
    static let skyTeal  = Color(hex: 0x6CC4C9) // highlights, hairline borders, sparkles

    // Answer-feedback glows — soft, never a solid banner, never red.
    static let rightGlow = Color(hex: 0x9BE7A8) // soft mint (right)
    static let wrongGlow = Color(hex: 0xFFC58A) // warm apricot (wrong)

    // Neutral supports.
    static let ink      = Color(hex: 0x2C2622) // warm near-black text
    static let cream    = Color(hex: 0xFFF6EC) // page background
    static let lockGrey = Color(hex: 0xC9C1B8) // locked content only
    static let star     = Color(hex: 0xFFCC00) // star gold

    /// Six kid-avatar outfit colours (the only place other hues appear).
    static let avatarChoices: [Color] = [
        Color(hex: 0x1F6F78), // teal
        Color(hex: 0xC9793A), // copper
        Color(hex: 0x6CC4C9), // sky teal
        Color(hex: 0xE5714E), // coral
        Color(hex: 0x8E6BB0), // grape
        Color(hex: 0x4C9F70)  // leaf
    ]

    // Semantic aliases (tokens/colors.css "Semantic aliases").
    static let pageBg         = cream
    static let surfaceCard    = Color.white
    static let surfaceBand    = peach.opacity(0.5)     // the ONLY tinted band (map header)
    static let textBody       = ink
    static let textMuted      = ink.opacity(0.7)
    static let textSoft       = ink.opacity(0.6)
    static let textFaint      = ink.opacity(0.45)
    static let textHeading    = teal
    static let actionPrimary  = teal
    static let actionSecondary = copper
    static let actionDisabled = lockGrey
    static let borderField    = skyTeal.opacity(0.4)   // 1.5px hairline on fields
    static let borderBubble   = skyTeal.opacity(0.5)   // 2px on bubbles
    static let borderFocus    = teal
    static let stateCorrectBg     = rightGlow.opacity(0.5)
    static let stateCorrectBorder = teal
    static let stateRetryBg       = wrongGlow.opacity(0.4)
    static let stateRetryBorder   = copper
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

// MARK: - Shape (tokens/shape.css)

/// Continuous-corner radii, exactly as written in the tokens.
enum Radius {
    static let field:  CGFloat = 16 // text + code fields
    static let key:    CGFloat = 18 // parent keypad key
    static let bubble: CGFloat = 20 // speech bubble, level row
    static let button: CGFloat = 22 // BigButton, ChoiceButton, DashCard
    // pill = Capsule() for chips and badges
}

/// Border widths carry state instead of shadow.
enum Border {
    static let hairline: CGFloat = 1
    static let field:    CGFloat = 1.5
    static let bubble:   CGFloat = 2
    static let avatar:   CGFloat = 3
    static let choice:   CGFloat = 3
    static let levelRing: CGFloat = 4  // translucent teal ring on the current level
    static let holdRing:  CGFloat = 12 // grown-up press-and-hold ring
}

// MARK: - Motion (tokens/motion.css)

/// Durations, easings and transform values. SwiftUI easeInOut throughout; the
/// only spring is the lesson step change.
enum Motion {
    static let press:     Double = 0.12
    static let glow:      Double = 0.40
    static let step:      Double = 0.40
    static let cheer:     Double = 0.35
    static let burst:     Double = 0.70
    static let burstFade: Double = 0.45
    static let idle:      Double = 1.60
    static let wave:      Double = 0.50

    static let pressOpacity: Double  = 0.85
    static let pressScale:   CGFloat = 0.98
    static let popScale:     CGFloat = 1.04
    static let breatheScale: CGFloat = 1.015
    static let cheerScale:   CGFloat = 1.06
    static let wobbleDeg:    Double  = 3
    static let burstRadius:  CGFloat = 130
}

// MARK: - Typography roles (tokens/typography.css)

/// SF Pro at the standard iOS text styles — the semantic roles from the tokens.
/// Kept as Dynamic-Type text styles so the kid-facing copy still scales.
extension Font {
    static let screenTitle  = Font.largeTitle.weight(.heavy)  // 34, one per screen
    static let sectionTitle = Font.title3.weight(.bold)       // 20 semibold/bold rows
    static let question     = Font.title2.weight(.bold)       // 22 questions
    static let bubble       = Font.title3.weight(.semibold)   // 20 Penny bubbles
    static let buttonLabel  = Font.title3.weight(.bold)       // 20 button labels
    static let rowTitle     = Font.headline                   // 17 semibold rows
    static let rowSub       = Font.subheadline                // 15 summaries
}

// MARK: - Button styles

/// Big, rounded, kid-friendly primary button (radius 22, 18px vertical padding).
/// Uniform press feedback: opacity 0.85 + scale 0.98, nothing else.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Palette.teal
    var textColor: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? Motion.pressOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .animation(.easeInOut(duration: Motion.press), value: configuration.isPressed)
    }
}

/// The uniform press feedback for every non-primary tappable surface (level
/// rows, avatar tiles, keypad keys): opacity 0.85 + scale 0.98, nothing else.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Motion.pressOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .animation(.easeInOut(duration: Motion.press), value: configuration.isPressed)
    }
}

extension View {
    /// The flat cream page background used across every kid-facing screen.
    /// No gradients, no texture, no photography — just flat cream.
    func kidPageBackground() -> some View {
        self.background(Palette.pageBg.ignoresSafeArea())
    }
}
