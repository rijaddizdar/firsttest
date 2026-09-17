//
//  PennyView.swift
//  Penny, rendered from the captain's hand-designed character sheet.
//
//  The five poses were cropped from a provided character sheet, cut to
//  transparency and exported to Assets.xcassets (Penny/*). They are PLACEHOLDER
//  art: the shipped app will use a commissioned glossy 3D Penny (pre-rendered
//  clips, then live RealityKit — README section 8). Penny is an armadillo whose
//  shell bands are rows of coins (Penny Design System, "The character").
//
//  Motion follows the design-system rules: a gentle 1.6s breathe at scale 1.015,
//  a 1.06 cheer over 350ms. Under Reduce Motion she holds a still pose and only
//  fades — nothing bounces, wobbles or flies.
//

import SwiftUI

/// Penny's pose for a given moment.
enum PennyMood {
    case idle       // hero, waving hello (breathing)
    case wave       // greeting (same waving pose)
    case cheer      // celebrate / right answer — arms up, open-mouth smile
    case celebrate  // lesson complete — arms up, closed-eye smile
    case encourage  // wrong answer — gentle, hands together
    case curl       // thinking / risky — rolled into a coin ball, peeking out
}

struct PennyView: View {
    var mood: PennyMood = .idle
    var size: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: size)
            .scaleEffect(breatheScale)
            .animation(idleAnimation, value: animate)
            .onAppear { animate = true }
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)
    }

    // MARK: Pose art

    private var imageName: String {
        switch mood {
        case .idle, .wave: return "penny-wave"
        case .cheer:       return "penny-cheer-open"
        case .celebrate:   return "penny-cheer"
        case .encourage:   return "penny-encourage"
        case .curl:        return "penny-curl"
        }
    }

    // MARK: Motion (all no-ops under Reduce Motion)

    private var breatheScale: CGFloat {
        guard !reduceMotion, animate else { return 1 }
        switch mood {
        case .cheer, .celebrate: return Motion.cheerScale   // 1.06
        case .idle, .wave:       return Motion.breatheScale // 1.015
        case .encourage, .curl:  return 1
        }
    }

    private var idleAnimation: Animation? {
        guard !reduceMotion else { return .easeInOut(duration: Motion.glow) } // fade only
        switch mood {
        case .cheer, .celebrate: return .easeInOut(duration: Motion.cheer).repeatForever(autoreverses: true)
        case .idle, .wave:       return .easeInOut(duration: Motion.idle).repeatForever(autoreverses: true)
        case .encourage, .curl:  return .easeInOut(duration: Motion.glow)
        }
    }

    private var accessibilityText: String {
        switch mood {
        case .idle, .wave:       return "Penny the armadillo, waving hello"
        case .cheer, .celebrate: return "Penny the armadillo, cheering"
        case .encourage:         return "Penny the armadillo, hands together, encouraging you"
        case .curl:              return "Penny the armadillo, curled into a coin ball"
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        PennyView(mood: .wave, size: 120)
        PennyView(mood: .cheer, size: 120)
        PennyView(mood: .celebrate, size: 120)
        PennyView(mood: .encourage, size: 120)
        PennyView(mood: .curl, size: 120)
    }
    .padding()
    .background(Palette.cream)
}
