//
//  SharedUI.swift
//  Small reusable pieces, ported from the Penny Design System components:
//  the Fluent 3D icon wrapper, Penny's speech bubble (the one shadow in the
//  app), the full-screen answer glow, the coin/sparkle burst, reward chips and
//  the star row — plus a Reduce-Motion-safe haptic helper.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Fluent Emoji 3D icon

/// Reward and level art: Fluent Emoji 3D (Microsoft, MIT licence) rendered as a
/// picture from the asset catalog. Glossy 3D is the only decorative icon style;
/// never mix in a flat or line icon at picture scale. See the credits line in
/// the grown-up area and App/Resources/FLUENT-EMOJI-LICENSE.txt.
struct FluentIcon: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Speech bubble

/// A rounded speech bubble for Penny's lines. Penny always uses the child's name.
/// This bubble carries the ONLY drop shadow in the whole app: 0 3px 6px rgba(0,0,0,0.08).
struct SpeechBubble: View {
    let text: String
    var tint: Color = .white

    var body: some View {
        Text(text)
            .font(.bubble)
            .foregroundStyle(Palette.textBody)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                    .stroke(Palette.borderBubble, lineWidth: Border.bubble)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3) // the one shadow
    }
}

// MARK: - Full-screen answer glow

/// Soft full-screen radial glow for answer feedback. Right = soft mint spreading
/// from the chosen answer (centre), wrong = warm apricot from the top edge.
/// NEVER a solid banner, never red, never an X. Colour is only ONE signal (badge
/// + words + Penny carry it too), so this is safe for colour-blind children.
struct AnswerGlow: View {
    enum Kind { case right, wrong }
    let kind: Kind

    var body: some View {
        let color = kind == .right ? Palette.rightGlow : Palette.wrongGlow
        RadialGradient(
            colors: [color.opacity(kind == .right ? 0.55 : 0.5), .clear],
            center: kind == .right ? .center : .top,
            startRadius: 20,
            endRadius: 520
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Coin / sparkle burst

/// A short burst of ~14 play coins (copper) and sparkles (sky teal) for a right
/// answer / celebration. They fly out ~130px over 700ms, then fade over 450ms.
/// Under Reduce Motion the pieces fade in place instead of flying out.
struct CoinBurst: View {
    var isActive: Bool
    var pieceCount = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false   // flown outward
    @State private var faded = false      // faded away at the end of the burst

    var body: some View {
        ZStack {
            ForEach(0..<pieceCount, id: \.self) { i in
                let sparkle = i % 3 == 0
                Circle()
                    .fill(sparkle ? Palette.skyTeal : Palette.copper)
                    .frame(width: sparkle ? 18 : 14, height: sparkle ? 18 : 14)
                    .offset(offset(for: i))
                    .opacity(pieceOpacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in trigger(active) }
        .onAppear { if isActive { trigger(true) } }
    }

    /// Coins are visible while they fly out, then gently fade. Under Reduce
    /// Motion they simply fade in place (no flying), never invisible.
    private var pieceOpacity: Double {
        guard launched else { return 0 }
        if reduceMotion { return 0.9 }
        return faded ? 0 : 1
    }

    private func trigger(_ active: Bool) {
        guard active else { launched = false; faded = false; return }
        launched = false; faded = false
        if reduceMotion {
            withAnimation(.easeInOut(duration: Motion.glow)) { launched = true }
        } else {
            withAnimation(.easeOut(duration: Motion.burst)) { launched = true } completion: {
                withAnimation(.easeIn(duration: Motion.burstFade)) { faded = true }
            }
        }
    }

    private func offset(for i: Int) -> CGSize {
        guard launched, !reduceMotion else { return .zero }
        let angle = Double(i) / Double(pieceCount) * 2 * .pi
        let radius = Motion.burstRadius
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius - 40)
    }
}

// MARK: - Haptics (iOS only, silent no-op elsewhere)

enum Haptics {
    /// Light tap for a right answer (light on right, none on wrong).
    static func rightAnswerTap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - Reward chip

/// Small white capsule showing a reward count (stars / coins / streak).
/// The streak icon is a COIN, never a flame. 1px hairline border in the tint.
struct RewardChip: View {
    let icon: String   // Fluent icon name
    let value: String
    var tint: Color = Palette.teal

    var body: some View {
        HStack(spacing: 6) {
            FluentIcon(name: icon, size: 22)
            Text(value).font(.rowTitle).foregroundStyle(Palette.textBody)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(tint, lineWidth: Border.hairline))
    }
}

/// A row of up to 3 stars. Earned = a glossy Fluent star; unearned = a grey
/// disc (never an X).
struct StarRow: View {
    let earned: Int
    var total = 3
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                if i < earned {
                    FluentIcon(name: "star", size: size)
                } else {
                    Circle()
                        .fill(Palette.lockGrey.opacity(0.5))
                        .frame(width: size, height: size)
                }
            }
        }
        .accessibilityLabel("\(earned) of \(total) stars")
    }
}
