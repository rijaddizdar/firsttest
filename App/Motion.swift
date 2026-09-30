//
//  Motion.swift
//  The small amount of movement that makes the app feel alive rather than
//  printed: things arrive, rewards react, and the level you can play asks to be
//  tapped.
//
//  Two rules hold everything here together.
//
//  1. It is all ENTRANCE and REACTION, never decoration. Nothing loops in a
//     child's peripheral vision while they are trying to read a question. The
//     Penny Design System is deliberately calm — `breatheScale` is 1.015 — and
//     this file does not raise those numbers; it adds movement the system did
//     not have, using the system's own durations from `Motion`.
//
//  2. Reduce Motion removes the movement, not the content. Every effect here
//     collapses to "already arrived" — never to a blank screen, and never to a
//     fade that still slides. README section 3: under Reduce Motion nothing
//     bounces, wobbles or flies.
//

import SwiftUI

// MARK: - Arriving

/// Fade and rise into place, optionally after a short wait so a list arrives as
/// a run rather than all at once.
private struct ArriveModifier: ViewModifier {
    let delay: Double
    let distance: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived || reduceMotion ? 0 : distance)
            .onAppear {
                guard !arrived else { return }
                if reduceMotion {
                    // Still fade, so nothing pops into existence, but never move.
                    withAnimation(.easeOut(duration: Motion.glow)) { arrived = true }
                } else {
                    withAnimation(.spring(duration: Motion.step, bounce: 0.22).delay(delay)) {
                        arrived = true
                    }
                }
            }
    }
}

/// A gentle pulse that says "this one". Used once per screen at most, on the
/// thing a child is meant to tap next.
private struct InvitePulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(out && !reduceMotion ? Motion.popScale : 1)
            .animation(reduceMotion ? nil
                       : .easeInOut(duration: Motion.idle).repeatForever(autoreverses: true),
                       value: out)
            .onAppear { out = true }
    }
}

/// Pops when its value changes — a reward that reacts is worth far more than a
/// reward that merely updates.
private struct PopOnChange<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped && !reduceMotion ? Motion.cheerScale : 1)
            .animation(.spring(duration: Motion.cheer, bounce: 0.45), value: popped)
            .onChange(of: value) { _, _ in
                guard !reduceMotion else { return }
                popped = true
                Task {
                    try? await Task.sleep(for: .seconds(Motion.cheer))
                    popped = false
                }
            }
    }
}

extension View {
    /// Arrive in place. `index` staggers a list so it reads as a run.
    func arrives(index: Int = 0, distance: CGFloat = 14, step: Double = 0.055) -> some View {
        modifier(ArriveModifier(delay: Double(index) * step, distance: distance))
    }

    /// Breathe gently, to say "tap this one".
    func invitesATap() -> some View { modifier(InvitePulse()) }

    /// Pop whenever `value` changes.
    func pops<V: Equatable>(on value: V) -> some View { modifier(PopOnChange(value: value)) }
}
