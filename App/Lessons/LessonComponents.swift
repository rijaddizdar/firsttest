//
//  LessonComponents.swift
//  The pieces every lesson screen is built from, so all seven screen types look
//  like one app: the top bar, Penny with her bubble, the picture answer card,
//  the concept card, and the content width that keeps a lesson readable on an
//  iPad instead of stretching it across 13 inches.
//
//  Visuals come from the Penny Design System tokens in Theme.swift — radii,
//  border widths, motion values and the palette. Nothing here hard-codes a
//  colour or a corner radius.
//

import SwiftUI

// MARK: - Top bar

/// Close button, the lesson or question title, and a "Sample" flag for scaffold
/// content so nobody mistakes it for a written lesson.
struct LessonTopBar: View {
    let title: String
    var isSample = false
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2).foregroundStyle(Palette.ink.opacity(0.35))
            }
            .accessibilityLabel("Close lesson")
            Spacer()
            VStack(spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.ink.opacity(0.7))
                if isSample {
                    Text("SAMPLE")
                        .font(.caption2.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(Palette.copper)
                }
            }
            Spacer()
            // Balance the layout.
            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.clear)
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }
}

// MARK: - Penny with her line

/// Penny and her speech bubble, the header of every question screen. Penny's
/// pose is the engine's, so it carries the right/wrong signal along with the
/// glow, the badge and the words.
struct LessonPennyHeader: View {
    let mood: PennyMood
    let line: String
    var pennySize: CGFloat = 120

    var body: some View {
        VStack(spacing: 14) {
            PennyView(mood: mood, size: pennySize)
            if !line.isEmpty {
                SpeechBubble(text: line)
                    .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Answer card

/// The big picture answer button shared by Tap to choose, Story choice and the
/// Sort it baskets. Right = soft mint fill with a check; wrong = warm apricot
/// with a hint light bulb. Never a red X, and colour is never the only signal.
struct AnswerCard: View {
    enum Result { case normal, correct, tryAgain }

    let icon: String
    let label: String
    var caption: String?
    var result: Result = .normal
    var wobble = false
    var minHeight: CGFloat = 0
    var iconSize: CGFloat = 56
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                FluentIcon(name: icon, size: iconSize)
                Text(label)
                    .font(.buttonLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textBody)
                if let caption {
                    Text(caption)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                badge.frame(height: 28)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(border, lineWidth: Border.choice)
            )
            .scaleEffect(result == .correct && !reduceMotion ? Motion.popScale : 1)
            .rotationEffect(.degrees(wobble && !reduceMotion ? Motion.wobbleDeg : 0))
            .animation(.easeInOut(duration: Motion.press).repeatCount(3, autoreverses: true), value: wobble)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    /// A check on right, a hint light bulb on a try-again — never an X.
    private var badge: some View {
        Group {
            switch result {
            case .correct:  FluentIcon(name: "check-mark", size: 26)
            case .tryAgain: FluentIcon(name: "light-bulb", size: 26)
            case .normal:   Color.clear.frame(width: 26, height: 26)
            }
        }
    }

    private var fill: Color {
        switch result {
        case .correct:  return Palette.stateCorrectBg
        case .tryAgain: return Palette.stateRetryBg
        case .normal:   return Palette.surfaceCard
        }
    }

    private var border: Color {
        switch result {
        case .correct:  return Palette.stateCorrectBorder
        case .tryAgain: return Palette.stateRetryBorder
        case .normal:   return Palette.borderField
        }
    }

    private var accessibilityValue: String {
        switch result {
        case .correct:  return "Correct"
        case .tryAgain: return "Try again"
        case .normal:   return ""
        }
    }
}

// MARK: - Concept card (Learn)

/// One idea on a Learn screen: a picture, a badge word and a short caption.
struct ConceptCard: View {
    let icon: String
    let badge: String
    let badgeColor: Color
    let caption: String

    var body: some View {
        VStack(spacing: 12) {
            FluentIcon(name: icon, size: 64)
            Text(badge)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(badgeColor, in: Capsule())
            Text(caption)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
    }
}

// MARK: - Prompt

/// The question itself, in the question type role from the design tokens.
struct LessonPrompt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.question)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.textBody)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
    }
}

// MARK: - Layout

extension View {
    /// Lessons are read, so they get a comfortable measure and sit in the middle
    /// of a wide screen rather than stretching over a 13-inch iPad.
    func lessonContentWidth() -> some View {
        frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
    }
}
