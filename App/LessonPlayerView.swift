//
//  LessonPlayerView.swift
//  Screen 4: one fully playable lesson — Level 2, "Needs & Wants" (README §4).
//
//  Flow: Hello (greets the kid by name) -> Learn -> Tap-to-choose question(s)
//  with right / wrong answer states -> Lesson complete (stars, coins, streak).
//
//  Right answer  : soft green full-screen glow, coins & sparkles, Penny cheers.
//  Wrong answer  : warm apricot glow, gentle wobble, Penny curls up, "try again".
//                  NEVER a red X, buzzer, or lost life (README §3).
//  Reduce Motion : the glow and messages fade in; nothing bounces or wobbles.
//

import SwiftUI

// MARK: - Lesson content model

private struct Question {
    let prompt: String
    let pennyHint: String          // Penny's nudge shown with the question
    let choices: [Choice]
    struct Choice: Identifiable {
        let id = UUID()
        let label: String
        let symbol: String
        let isCorrect: Bool
    }
    let correctLine: String        // Penny's line on a right answer
    let wrongLine: String          // Penny's kind hint on a wrong answer
}

/// The Needs & Wants questions, worded per README §4 and the §7 tone rules.
private let needsAndWantsQuestions: [Question] = [
    Question(
        prompt: "It's snowing outside. Is a warm coat a need or a want?",
        pennyHint: "Look at the picture, {name}!",
        choices: [
            .init(label: "Need", symbol: "thumbs-up", isCorrect: true),
            .init(label: "Want", symbol: "balloon", isCorrect: false)
        ],
        correctLine: "Yes, {name}! A coat keeps us warm and safe. That's a need!",
        wrongLine: "Good try, {name}! See how the coat keeps her warm in the snow? That makes it a need."
    ),
    Question(
        prompt: "You are thirsty on a hot day. Is water a need or a want?",
        pennyHint: "Think about your body, {name}.",
        choices: [
            .init(label: "Need", symbol: "droplet", isCorrect: true),
            .init(label: "Want", symbol: "balloon", isCorrect: false)
        ],
        correctLine: "That's it, {name}! Our bodies need water to stay healthy.",
        wrongLine: "Good try, {name}! We can't stay healthy without water, so water is a need."
    )
]

// MARK: - Player

struct LessonPlayerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sub-screens inside the lesson.
    private enum Step: Equatable {
        case hello, learn, question(Int), complete
    }

    @State private var step: Step = .hello

    // Answer feedback state for the current question.
    @State private var feedback: AnswerGlow.Kind?     // nil = no glow shown
    @State private var chosenID: UUID?
    @State private var wobbleID: UUID?                 // which wrong choice wobbles
    @State private var burst = false

    // Running lesson tally.
    @State private var mistakes = 0

    private let levelID = 2

    private var kidName: String { app.selectedKid?.name ?? "friend" }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            switch step {
            case .hello:            helloScreen
            case .learn:            learnScreen
            case .question(let i):  questionScreen(index: i)
            case .complete:         completeScreen
            }

            // Full-screen answer glow sits above the content, below no controls.
            if let feedback {
                AnswerGlow(kind: feedback)
                    .transition(.opacity)
            }
        }
        // Screenshot / UI-test hook only: jump straight to the first question in a
        // right- or wrong-answer glow state. Absent env var = normal play.
        .onAppear(perform: applyUITestFeedbackIfNeeded)
        // Motion-aware: fade-only when Reduce Motion is on.
        .animation(reduceMotion ? .easeInOut(duration: 0.4) : .spring(duration: 0.4), value: step)
        .animation(.easeInOut(duration: 0.4), value: feedback)
    }

    // MARK: Hello

    private var helloScreen: some View {
        VStack(spacing: 26) {
            LessonTopBar(title: "Needs & Wants") { exit() }
            Spacer()
            PennyView(mood: .wave, size: 180)
            // Penny greets the child BY NAME (README §3 / §6).
            SpeechBubble(text: "Hi, \(kidName)! Today we'll learn about needs and wants!")
                .padding(.horizontal, 24)
            Spacer()
            Button("Let's go!") { step = .learn }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: Learn

    private var learnScreen: some View {
        VStack(spacing: 22) {
            LessonTopBar(title: "Needs & Wants") { exit() }
            Text("Needs and Wants")
                .font(.screenTitle).foregroundStyle(Palette.textHeading)

            // Two picture cards — a NEED and a WANT (README §4 step 2).
            HStack(spacing: 16) {
                ConceptCard(icon: "coat",
                            badge: "NEED", badgeColor: Palette.teal,
                            caption: "Something we must have to stay safe and healthy.")
                ConceptCard(icon: "balloon",
                            badge: "WANT", badgeColor: Palette.copper,
                            caption: "A fun extra. Nice, but we're okay without it.")
            }
            .padding(.horizontal, 20)

            PennyView(mood: .idle, size: 110)
            Spacer()
            Button("I'm ready") { step = .question(0) }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: Question

    private func questionScreen(index: Int) -> some View {
        let q = needsAndWantsQuestions[index]
        let answered = feedback == .right   // only a right answer advances
        return VStack(spacing: 20) {
            LessonTopBar(title: "Question \(index + 1) of \(needsAndWantsQuestions.count)") { exit() }

            // Penny reacts: cheer on right, curl on wrong, else idle.
            PennyView(mood: pennyMood, size: 120)

            SpeechBubble(text: bubbleText(for: q, answered: answered))
                .padding(.horizontal, 24)

            Text(q.prompt)
                .font(.question)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textBody)
                .padding(.horizontal, 24)

            // Big picture answer buttons (README §3 "Tap to choose").
            HStack(spacing: 16) {
                ForEach(q.choices) { choice in
                    ChoiceButton(
                        choice: choice,
                        state: choiceState(choice, answered: answered),
                        wobble: wobbleID == choice.id && !reduceMotion
                    ) {
                        pick(choice, in: q, index: index)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            if answered {
                Button(index + 1 < needsAndWantsQuestions.count ? "Next" : "Finish") {
                    advance(from: index)
                }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        .overlay(CoinBurst(isActive: burst).allowsHitTesting(false))
    }

    // MARK: Complete (Yay!)

    private var completeScreen: some View {
        // Fewer mistakes -> more stars (3 for a clean run, min 1).
        let stars = max(1, 3 - mistakes)
        let coins = 10
        return VStack(spacing: 22) {
            Spacer()
            PennyView(mood: .celebrate, size: 180)
            Text("Lesson done, \(kidName)!")
                .font(.screenTitle).foregroundStyle(Palette.textHeading)
            StarRow(earned: stars, size: 40)
            HStack(spacing: 12) {
                RewardChip(icon: "coin", value: "+\(coins)", tint: Palette.copper)
                // Streak icon is a coin, never a flame.
                RewardChip(icon: "coin",
                           value: "\((app.selectedKid?.currentStreak ?? 0) + 1)-day", tint: Palette.teal)
            }
            Text("You kept trying, and you got it!")
                .font(.title3).foregroundStyle(Palette.textMuted)
            Spacer()
            Button("Back to the map") {
                // Commit rewards once, then leave.
                app.completeLesson(levelID: levelID, stars: stars, coins: coins)
                app.route = .lessonMap
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .overlay(CoinBurst(isActive: true).allowsHitTesting(false))
        .onAppear { Haptics.success() }
    }

    // MARK: - Answer handling

    private func pick(_ choice: Question.Choice, in q: Question, index: Int) {
        guard feedback != .right else { return }   // already correct; ignore
        chosenID = choice.id
        if choice.isCorrect {
            feedback = .right
            burst = true
            Haptics.rightAnswerTap()
        } else {
            // Gentle wrong-answer state: apricot glow, wobble, Penny curls.
            // No red X, no buzzer, no lost life. The child simply tries again.
            mistakes += 1
            feedback = .wrong
            wobbleID = choice.id
            // Clear the apricot glow after a beat so the question is ready again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if feedback == .wrong {
                    withAnimation { feedback = nil; wobbleID = nil }
                }
            }
        }
    }

    private func advance(from index: Int) {
        resetFeedback()
        if index + 1 < needsAndWantsQuestions.count {
            step = .question(index + 1)
        } else {
            step = .complete
        }
    }

    private func resetFeedback() {
        feedback = nil; chosenID = nil; wobbleID = nil; burst = false
    }

    private func exit() {
        resetFeedback()
        app.route = .lessonMap
    }

    /// Screenshots only: pre-seed the first question in a right/wrong glow state.
    private func applyUITestFeedbackIfNeeded() {
        guard let kind = ProcessInfo.processInfo.environment["UITEST_LESSON_FEEDBACK"] else { return }
        let q = needsAndWantsQuestions[0]
        step = .question(0)
        switch kind {
        case "right":
            if let correct = q.choices.first(where: { $0.isCorrect }) {
                chosenID = correct.id; feedback = .right; burst = true
            }
        case "wrong":
            if let wrong = q.choices.first(where: { !$0.isCorrect }) {
                chosenID = wrong.id; wobbleID = wrong.id; feedback = .wrong; mistakes = 1
            }
        case "complete":
            step = .complete
        default: break
        }
    }

    // MARK: - View helpers

    private var pennyMood: PennyMood {
        switch feedback {
        case .right: return .cheer      // celebrate — arms up
        case .wrong: return .encourage  // gentle, hands together (never a scold)
        case nil:    return .idle
        }
    }

    private func bubbleText(for q: Question, answered: Bool) -> String {
        let name = kidName
        switch feedback {
        case .right: return q.correctLine.replacingOccurrences(of: "{name}", with: name)
        case .wrong: return q.wrongLine.replacingOccurrences(of: "{name}", with: name)
        case nil:    return q.pennyHint.replacingOccurrences(of: "{name}", with: name)
        }
    }

    private func choiceState(_ choice: Question.Choice, answered: Bool) -> ChoiceButton.State {
        if feedback == .right && choice.id == chosenID { return .correct }
        if feedback == .wrong && choice.id == chosenID { return .tryAgain }
        return .normal
    }
}

// MARK: - Sub-components

private struct LessonTopBar: View {
    let title: String
    let onClose: () -> Void
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2).foregroundStyle(Palette.ink.opacity(0.35))
            }
            .accessibilityLabel("Close lesson")
            Spacer()
            Text(title).font(.headline).foregroundStyle(Palette.ink.opacity(0.7))
            Spacer()
            // Balance the layout.
            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.clear)
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }
}

private struct ConceptCard: View {
    let icon: String       // Fluent icon name
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
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
    }
}

private struct ChoiceButton: View {
    enum State { case normal, correct, tryAgain }
    let choice: Question.Choice
    let state: State
    let wobble: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                FluentIcon(name: choice.symbol, size: 56)
                Text(choice.label)
                    .font(.buttonLabel)
                    .foregroundStyle(fg)
                // Badge is a check (right) or a hint light bulb (wrong) — never
                // an X. Colour is never the only signal (README §3).
                Group {
                    switch state {
                    case .correct:  FluentIcon(name: "check-mark", size: 26)
                    case .tryAgain: FluentIcon(name: "light-bulb", size: 26)
                    case .normal:   Color.clear.frame(width: 26, height: 26)
                    }
                }
                .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).stroke(border, lineWidth: Border.choice))
            .scaleEffect(state == .correct ? Motion.popScale : 1)
            .rotationEffect(.degrees(wobble ? Motion.wobbleDeg : 0))
            .animation(.easeInOut(duration: Motion.press).repeatCount(3, autoreverses: true), value: wobble)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.label)
        .accessibilityValue(accessibilityValue)
    }

    private var fg: Color { Palette.textBody }
    private var bg: Color {
        switch state {
        case .correct:  return Palette.stateCorrectBg
        case .tryAgain: return Palette.stateRetryBg
        case .normal:   return .white
        }
    }
    private var border: Color {
        switch state {
        case .correct:  return Palette.stateCorrectBorder
        case .tryAgain: return Palette.stateRetryBorder
        case .normal:   return Palette.borderField
        }
    }
    private var accessibilityValue: String {
        switch state {
        case .correct:  return "Correct"
        case .tryAgain: return "Try again"
        case .normal:   return ""
        }
    }
}

#Preview {
    LessonPlayerView().environmentObject(AppState())
}
