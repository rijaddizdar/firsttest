//
//  PennyView.swift
//  A PLACEHOLDER 2D Penny the Pangolin, drawn from plain SwiftUI shapes.
//
//  The real app ships a commissioned glossy 3D Penny (pre-rendered clips, then
//  live RealityKit — README section 8). This stand-in exists only so the mock-up
//  reads correctly: copper body, coin scales, peach face, teal scarf, big eyes.
//  No external art, no 3D, no third-party packages.
//

import SwiftUI

/// Penny's expression for a given moment (README section 2 "How Penny moves").
enum PennyMood {
    case idle       // breathing / waving
    case cheer      // celebrate: hops, coins fly
    case curl       // rolls into a coin ball after a wrong answer, then peeks out
    case wave       // greeting
}

struct PennyView: View {
    var mood: PennyMood = .idle
    var size: CGFloat = 160
    var scarfColor: Color = Palette.teal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            if mood == .curl {
                curledPenny
            } else {
                uprightPenny
            }
        }
        .frame(width: size, height: size)
        // Gentle, looping idle motion. When Reduce Motion is on we hold a still
        // pose and only fade — never bounce or wobble (README section 3).
        .scaleEffect(bounceScale)
        .rotationEffect(.degrees(mood == .cheer && !reduceMotion && animate ? -4 : 0))
        .animation(idleAnimation, value: animate)
        .onAppear { animate = true }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Poses

    private var uprightPenny: some View {
        ZStack {
            // Body — copper, rounded.
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(Palette.copper)
                .frame(width: size * 0.72, height: size * 0.82)
                .offset(y: size * 0.05)

            // Coin scales on the back/head: little shiny discs.
            coinScales

            // Face — peach.
            Circle()
                .fill(Palette.peach)
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(y: -size * 0.12)
                .overlay(faceFeatures.offset(y: -size * 0.12))

            // Teal knit scarf.
            Capsule()
                .fill(scarfColor)
                .frame(width: size * 0.56, height: size * 0.13)
                .offset(y: size * 0.11)

            // Little waving arm.
            Capsule()
                .fill(Palette.copper)
                .frame(width: size * 0.1, height: size * 0.22)
                .offset(x: size * 0.34, y: size * 0.02)
                .rotationEffect(.degrees(waveAngle), anchor: .bottom)
                .animation(waveAnimation, value: animate)
        }
    }

    /// Curl-up pose: a copper "coin ball" with a couple of scales and a peek.
    private var curledPenny: some View {
        ZStack {
            Circle()
                .fill(Palette.copper)
                .frame(width: size * 0.7, height: size * 0.7)
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Palette.skyTeal.opacity(0.9))
                    .frame(width: size * 0.12, height: size * 0.12)
                    .offset(x: cos(Double(i) / 6 * .pi * 2) * size * 0.22,
                            y: sin(Double(i) / 6 * .pi * 2) * size * 0.22)
            }
            // A peeking eye.
            Circle().fill(Palette.ink)
                .frame(width: size * 0.06, height: size * 0.06)
                .offset(x: -size * 0.06, y: -size * 0.02)
        }
    }

    private var coinScales: some View {
        ForEach(0..<5, id: \.self) { i in
            Circle()
                .fill(Palette.skyTeal)
                .overlay(Circle().stroke(Palette.teal.opacity(0.4), lineWidth: 1))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: CGFloat(i - 2) * size * 0.13, y: -size * 0.28)
        }
    }

    private var faceFeatures: some View {
        VStack(spacing: size * 0.04) {
            HStack(spacing: size * 0.12) {
                eye
                eye
            }
            // Snout.
            Capsule()
                .fill(Palette.copper.opacity(0.85))
                .frame(width: size * 0.12, height: size * 0.07)
        }
    }

    private var eye: some View {
        ZStack {
            Circle().fill(.white).frame(width: size * 0.1, height: size * 0.1)
            Circle().fill(Palette.ink).frame(width: size * 0.05, height: size * 0.05)
        }
    }

    // MARK: Motion helpers (all no-ops under Reduce Motion)

    private var bounceScale: CGFloat {
        guard !reduceMotion, animate else { return 1 }
        switch mood {
        case .cheer: return 1.06
        case .idle, .wave: return 1.015 // subtle "breathing"
        case .curl: return 1
        }
    }

    private var waveAngle: Double {
        guard !reduceMotion, animate, mood == .wave || mood == .cheer else { return 0 }
        return 18
    }

    private var idleAnimation: Animation? {
        guard !reduceMotion else { return .easeInOut(duration: 0.4) } // fade only
        switch mood {
        case .cheer: return .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
        case .idle, .wave: return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        case .curl: return .easeInOut(duration: 0.4)
        }
    }

    private var waveAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }

    private var accessibilityText: String {
        switch mood {
        case .idle:  return "Penny the pangolin, waving hello"
        case .wave:  return "Penny the pangolin, waving hello"
        case .cheer: return "Penny the pangolin, cheering"
        case .curl:  return "Penny the pangolin, curled into a coin ball"
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        PennyView(mood: .idle, size: 120)
        PennyView(mood: .cheer, size: 120)
        PennyView(mood: .curl, size: 120)
    }
    .padding()
    .background(Palette.cream)
}
