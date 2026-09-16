//
//  SharedUI.swift
//  Small reusable pieces: Penny's speech bubble, the coin/sparkle burst,
//  the full-screen answer glow, and a Reduce-Motion-safe haptic helper.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Speech bubble

/// A rounded speech bubble for Penny's lines. Penny always uses the child's name
/// (README section 3 / section 7 "Talk to the child").
struct SpeechBubble: View {
    let text: String
    var tint: Color = .white

    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.skyTeal.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}

// MARK: - Full-screen answer glow

/// Soft full-screen glow used for answer feedback (README section 3).
/// Right = soft mint green, wrong = warm apricot. NEVER a solid banner, never
/// red, never an X. Colour is only ONE of the signals (badge + words + Penny
/// carry it too), so this is safe for colour-blind children.
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

/// A short burst of play coins and sparkles for a right answer / celebration.
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
                Image(systemName: i % 3 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: i % 3 == 0 ? 18 : 14))
                    .foregroundStyle(i % 3 == 0 ? Palette.skyTeal : Palette.copper)
                    .offset(offset(for: i))
                    .opacity(pieceOpacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            trigger(active)
        }
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
            withAnimation(.easeIn(duration: 0.3)) { launched = true }
        } else {
            // Fly out (visible), then fade away.
            withAnimation(.easeOut(duration: 0.7)) { launched = true } completion: {
                withAnimation(.easeIn(duration: 0.45)) { faded = true }
            }
        }
    }

    private func offset(for i: Int) -> CGSize {
        guard launched, !reduceMotion else { return .zero }
        let angle = Double(i) / Double(pieceCount) * 2 * .pi
        let radius: CGFloat = 130
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius - 40)
    }
}

// MARK: - Haptics (iOS only, silent no-op elsewhere)

enum Haptics {
    /// Light tap for a right answer (README section 3 "Touch: a light haptic
    /// tap" on right, "None" on wrong). No-op on non-UIKit platforms so the file
    /// still parses on macOS.
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

/// Small pill showing a reward count (stars / coins / streak).
struct RewardChip: View {
    let symbol: String
    let value: String
    var tint: Color = Palette.teal

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.headline).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

/// A row of up to 3 stars (README section 3 "Up to 3 stars per lesson").
struct StarRow: View {
    let earned: Int
    var total = 3
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? Color.yellow : Palette.lockGrey)
            }
        }
        .accessibilityLabel("\(earned) of \(total) stars")
    }
}
