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
            .init(label: "Need", symbol: "hand.thumbsup.fill", isCorrect: true),
            .init(label: "Want", symbol: "balloon.fill", isCorrect: false)
        ],
        correctLine: "Yes, {name}! A coat keeps us warm and safe. That's a need!",
        wrongLine: "Good try, {name}! See how the coat keeps her warm in the snow? That makes it a need."
    ),
    Question(
        prompt: "You are thirsty on a hot day. Is water a need or a want?",
        pennyHint: "Think about your body, {name}.",
        choices: [
            .init(label: "Need", symbol: "drop.fill", isCorrect: true),
            .init(label: "Want", symbol: "gamecontroller.fill", isCorrect: false)
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
        VStack(spacing: Metric.lg) {
            LessonTopBar(title: "Needs & Wants") { exit() }
            Spacer()
            PennyView(mood: .wave, size: 190)
            // Penny greets the child BY NAME (README §3 / §6).
            SpeechBubble(text: "Hi, \(kidName)! Today we'll learn about needs and wants!")
                .padding(.horizontal, Metric.pagePadding)
            Spacer()
            Button("Let's go!") {
                Haptics.selection()
                step = .learn
            }
                .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "play.fill"))
                .padding(.horizontal, Metric.pagePadding).padding(.bottom, Metric.lg)
        }
    }

    // MARK: Learn

    private var learnScreen: some View {
        VStack(spacing: Metric.lg) {
            LessonTopBar(title: "Needs & Wants") { exit() }
            Text("Needs and Wants")
                .font(.kidTitle).foregroundStyle(Palette.teal)

            // Two picture cards — a NEED and a WANT (README §4 step 2).
            HStack(spacing: Metric.md) {
                ConceptCard(symbol: "snowflake",
                            badge: "NEED", badgeColor: Palette.teal,
                            caption: "Something we must have to stay safe and healthy.")
                ConceptCard(symbol: "balloon.2.fill",
                            badge: "WANT", badgeColor: Palette.copper,
                            caption: "A fun extra. Nice, but we're okay without it.")
            }
            .padding(.horizontal, Metric.lg)

            PennyView(mood: .idle, size: 120)
            Spacer()
            Button("I'm ready") {
                Haptics.selection()
                step = .question(0)
            }
                .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "checkmark"))
                .padding(.horizontal, Metric.pagePadding).padding(.bottom, Metric.lg)
        }
    }

    // MARK: Question

    private func questionScreen(index: Int) -> some View {
        let q = needsAndWantsQuestions[index]
        let answered = feedback == .right   // only a right answer advances
        return VStack(spacing: Metric.md) {
            LessonTopBar(title: "Question \(index + 1) of \(needsAndWantsQuestions.count)",
                         progress: Double(index) / Double(needsAndWantsQuestions.count)) { exit() }

            // Penny reacts: cheer on right, curl on wrong, else idle.
            PennyView(mood: pennyMood, size: 128)
                .id(pennyMood)   // re-trigger her motion when the mood changes

            SpeechBubble(text: bubbleText(for: q, answered: answered))
                .padding(.horizontal, Metric.pagePadding)

            Text(q.prompt)
                .font(.kidTitle2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Metric.pagePadding)

            // Big picture answer buttons (README §3 "Tap to choose").
            HStack(spacing: Metric.md) {
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
            .padding(.horizontal, Metric.lg)

            Spacer()

            if answered {
                Button(index + 1 < needsAndWantsQuestions.count ? "Next" : "Finish") {
                    Haptics.selection()
                    advance(from: index)
                }
                .buttonStyle(BigButtonStyle(fill: Palette.teal,
                                            icon: index + 1 < needsAndWantsQuestions.count ? "arrow.right" : "flag.checkered"))
                .padding(.horizontal, Metric.pagePadding).padding(.bottom, Metric.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(CoinBurst(isActive: burst).allowsHitTesting(false))
    }

    // MARK: Complete (Yay!)

    private var completeScreen: some View {
        // Fewer mistakes -> more stars (3 for a clean run, min 1).
        let stars = max(1, 3 - mistakes)
        let coins = 10
        return VStack(spacing: Metric.lg) {
            Spacer()
            PennyView(mood: .cheer, size: 190)
            Text("Lesson done, \(kidName)!")
                .font(.kidHero).multilineTextAlignment(.center)
                .foregroundStyle(Palette.teal)
                .padding(.horizontal, Metric.lg)
            // Stars pop in one at a time for a satisfying reveal.
            StarRow(earned: stars, size: 44, animated: true)
            HStack(spacing: Metric.sm) {
                RewardChip(symbol: "dollarsign.circle.fill", value: "+\(coins)", tint: Palette.copper)
                RewardChip(symbol: "circle.hexagongrid.fill",
                           value: "\((app.selectedKid?.currentStreak ?? 0) + 1)-day", tint: Palette.teal)
            }
            Text("You kept trying, and you got it!")
                .font(.kidBody).foregroundStyle(Palette.ink.opacity(0.65))
            Spacer()
            Button("Back to the map") {
                Haptics.selection()
                // Commit rewards once, then leave.
                app.completeLesson(levelID: levelID, stars: stars, coins: coins)
                app.route = .lessonMap
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "map.fill"))
            .padding(.horizontal, Metric.pagePadding).padding(.bottom, Metric.lg)
        }
        .overlay(CoinBurst(isActive: true, pieceCount: 26).allowsHitTesting(false))
        .onAppear {
            Haptics.success()
            SoundFX.play(.celebrate)
        }
    }

    // MARK: - Answer handling

    private func pick(_ choice: Question.Choice, in q: Question, index: Int) {
        guard feedback != .right else { return }   // already correct; ignore
        chosenID = choice.id
        if choice.isCorrect {
            feedback = .right
            burst = true
            Haptics.rightAnswerTap()
            SoundFX.play(.correct)
        } else {
            // Gentle wrong-answer state: apricot glow, wobble, Penny curls.
            // No red X, no buzzer, no lost life. The child simply tries again.
            mistakes += 1
            feedback = .wrong
            wobbleID = choice.id
            Haptics.gentleNudge()
            SoundFX.play(.tryAgain)
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
            // Screenshot the celebration screen (clean run -> 3 stars).
            mistakes = 0; step = .complete
        default: break
        }
    }

    // MARK: - View helpers

    private var pennyMood: PennyMood {
        switch feedback {
        case .right: return .cheer
        case .wrong: return .curl
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
    var progress: Double? = nil
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundStyle(Palette.ink.opacity(0.3))
                }
                .accessibilityLabel("Close lesson")
                Spacer()
                Text(title).font(.kidCaption).foregroundStyle(Palette.ink.opacity(0.65))
                Spacer()
                // Balance the layout.
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.clear)
            }
            if let progress {
                // A slim progress track for the question sequence.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.lockGrey.opacity(0.3))
                        Capsule().fill(LinearGradient(colors: [Palette.skyTeal, Palette.teal],
                                                      startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .padding(.horizontal, Metric.lg).padding(.top, Metric.md)
    }
}

private struct ConceptCard: View {
    let symbol: String
    let badge: String
    let badgeColor: Color
    let caption: String
    var body: some View {
        VStack(spacing: Metric.sm) {
            ZStack {
                Circle().fill(badgeColor.opacity(0.12)).frame(width: 84, height: 84)
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(badgeColor)
            }
            Text(badge)
                .font(.kidCaption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(
                    Capsule().fill(LinearGradient(colors: [badgeColor.lighter(0.1), badgeColor.darker(0.08)],
                                                  startPoint: .top, endPoint: .bottom))
                )
            Text(caption)
                .font(.kidFootnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Metric.md)
        .cardSurface(radius: 22)
    }
}

private struct ChoiceButton: View {
    enum State { case normal, correct, tryAgain }
    let choice: Question.Choice
    let state: State
    let wobble: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metric.sm) {
                ZStack {
                    Circle().fill(iconWell).frame(width: 76, height: 76)
                    Image(systemName: choice.symbol)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(iconTint)
                }
                Text(choice.label)
                    .font(.kidHeadline)
                    .foregroundStyle(fg)
                // Badge is a check (right) or a hint light bulb (wrong) — never
                // an X. Colour is never the only signal (README §3).
                Group {
                    switch state {
                    case .correct:  Label("Yes!", systemImage: "checkmark.circle.fill")
                    case .tryAgain: Label("Try again", systemImage: "lightbulb.fill")
                    case .normal:   Text(" ").opacity(0)
                    }
                }
                .font(.kidCaption)
                .foregroundStyle(state == .correct ? Palette.rightInk : Palette.copper)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metric.lg)
            .background(bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(border, lineWidth: 3))
            .softShadow()
            .scaleEffect(state == .correct && !reduceMotion ? 1.05 : 1)
            .rotationEffect(.degrees(wobble ? 3 : 0))
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: state)
            .animation(.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true), value: wobble)
        }
        .buttonStyle(PressableCard())
        .accessibilityLabel(choice.label)
        .accessibilityValue(accessibilityValue)
    }

    private var fg: Color { Palette.ink }
    private var iconTint: Color {
        switch state {
        case .correct:  return Palette.rightInk
        case .tryAgain: return Palette.copper
        case .normal:   return Palette.teal
        }
    }
    private var iconWell: Color {
        switch state {
        case .correct:  return Palette.rightGlow.opacity(0.6)
        case .tryAgain: return Palette.wrongGlow.opacity(0.5)
        case .normal:   return Palette.skyTeal.opacity(0.18)
        }
    }
    private var bg: some ShapeStyle {
        switch state {
        case .correct:  return AnyShapeStyle(Palette.rightGlow.opacity(0.35))
        case .tryAgain: return AnyShapeStyle(Palette.wrongGlow.opacity(0.3))
        case .normal:   return AnyShapeStyle(Color.white)
        }
    }
    private var border: Color {
        switch state {
        case .correct:  return Palette.rightInk
        case .tryAgain: return Palette.copper
        case .normal:   return Palette.skyTeal.opacity(0.4)
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
