//
//  SharedUI.swift
//  Small reusable pieces: Penny's speech bubble, the coin/sparkle burst, the
//  full-screen answer glow, reward chips + stars, and Reduce-Motion-safe haptic
//  and (default-OFF) sound helpers.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Speech bubble

/// A rounded speech bubble for Penny's lines, with a little tail pointing up
/// toward her. Penny always uses the child's name (README §3 / §7).
struct SpeechBubble: View {
    let text: String
    var tint: Color = .white
    var showTail = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Text(text)
            .font(.kidHeadline)
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    if showTail {
                        Triangle()
                            .fill(tint)
                            .frame(width: 26, height: 14)
                            .offset(y: -6)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(tint)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.skyTeal.opacity(0.35), lineWidth: 2)
            )
            .softShadow()
            .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { appeared = true; return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { appeared = true }
            }
    }
}

/// Small upward triangle for the speech-bubble tail.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Full-screen answer glow

/// Soft full-screen glow used for answer feedback (README §3). Right = soft mint
/// green (a gentle pulse), wrong = warm apricot. NEVER a solid banner, never
/// red, never an X. Colour is only ONE signal (badge + words + Penny carry it
/// too), so this is safe for colour-blind children.
struct AnswerGlow: View {
    enum Kind { case right, wrong }
    let kind: Kind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let color = kind == .right ? Palette.rightGlow : Palette.wrongGlow
        RadialGradient(
            colors: [color.opacity(kind == .right ? 0.6 : 0.52), .clear],
            center: kind == .right ? .center : .top,
            startRadius: 20,
            endRadius: pulse && !reduceMotion ? 620 : 520
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Coin / sparkle burst

/// A short burst of play coins and sparkles for a right answer / celebration.
/// Coins spin and arc outward with a little gravity, then fade. Under Reduce
/// Motion the pieces simply fade in place — never fly, never invisible.
struct CoinBurst: View {
    var isActive: Bool
    var pieceCount = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false
    @State private var faded = false

    var body: some View {
        ZStack {
            ForEach(0..<pieceCount, id: \.self) { i in
                piece(for: i)
                    .offset(offset(for: i))
                    .rotationEffect(.degrees(launched && !reduceMotion ? Double((i * 57) % 360) : 0))
                    .opacity(pieceOpacity)
                    .scaleEffect(launched ? 1 : 0.4)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in trigger(active) }
        .onAppear { if isActive { trigger(true) } }
    }

    @ViewBuilder
    private func piece(for i: Int) -> some View {
        switch i % 3 {
        case 0:
            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.skyTeal)
        case 1:
            // A little gold coin with a rim.
            Circle()
                .fill(LinearGradient(colors: [Palette.gold.lighter(0.2), Palette.gold, Palette.copper],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Palette.copperDeep.opacity(0.5), lineWidth: 1.5))
                .overlay(Image(systemName: "dollarsign").font(.system(size: 8, weight: .black)).foregroundStyle(Palette.copperDeep.opacity(0.7)))
                .frame(width: 18, height: 18)
        default:
            Image(systemName: "star.fill")
                .font(.system(size: 15))
                .foregroundStyle(Palette.gold)
        }
    }

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
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { launched = true } completion: {
                withAnimation(.easeIn(duration: 0.5)) { faded = true }
            }
        }
    }

    private func offset(for i: Int) -> CGSize {
        guard launched, !reduceMotion else { return .zero }
        let angle = Double(i) / Double(pieceCount) * 2 * .pi
        let radius: CGFloat = 120 + CGFloat((i * 37) % 60)
        // A little downward gravity so it arcs like a real toss.
        return CGSize(width: cos(angle) * radius,
                      height: sin(angle) * radius - 50 + CGFloat((i * 13) % 40))
    }
}

// MARK: - Haptics (iOS only, silent no-op elsewhere)

enum Haptics {
    /// Light tap for a right answer (README §3). No-op off UIKit so macOS parses.
    static func rightAnswerTap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// A soft, non-alarming tap for the gentle wrong-answer state (never a buzz).
    static func gentleNudge() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - Sound hooks (default OFF — no bundled audio required)

/// Simple sound-effect hook points. Deliberately OFF by default: the mock-up
/// ships no audio, and kid-app audio must be a considered, parent-controllable
/// choice. When real assets land, flip `enabled` and fill in `play(_:)`.
enum SoundFX {
    /// Master switch. Stays false until real, reviewed audio is bundled.
    static var enabled = false

    enum Cue { case correct, tryAgain, celebrate, tap }

    static func play(_ cue: Cue) {
        guard enabled else { return }
        // No-op placeholder: the real app plays a short bundled clip per cue.
        // Intentionally empty so nothing ships without deliberate sign-off.
    }
}

// MARK: - Reward chip

/// Small pill showing a reward count (stars / coins / streak), softly raised.
struct RewardChip: View {
    let symbol: String
    let value: String
    var tint: Color = Palette.teal

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.callout.weight(.bold)).foregroundStyle(tint)
            Text(value).font(.kidCallout).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(.white)
                .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
        )
        .softShadow()
    }
}

/// A row of up to 3 stars (README §3). When `animated`, they pop in one by one.
struct StarRow: View {
    let earned: Int
    var total = 3
    var size: CGFloat = 22
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(
                        i < earned
                        ? AnyShapeStyle(LinearGradient(colors: [Palette.gold.lighter(0.15), Palette.gold],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Palette.lockGrey.opacity(0.5))
                    )
                    .scaleEffect(scale(for: i))
                    .rotationEffect(.degrees(animated && !reduceMotion && i < shown ? 0 : (i < earned ? -20 : 0)))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(earned) of \(total) stars")
        .onAppear {
            guard animated, !reduceMotion else { shown = total; return }
            for i in 0..<earned {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 * Double(i) + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { shown = i + 1 }
                }
            }
        }
    }

    private func scale(for i: Int) -> CGFloat {
        guard animated, !reduceMotion else { return 1 }
        return i < shown ? 1 : (i < earned ? 0.1 : 1)
    }
}
