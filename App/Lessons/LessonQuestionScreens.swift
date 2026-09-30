//
//  LessonQuestionScreens.swift
//  Two of the four question screens: "Tap to choose" and "Story choice"
//  (README section 3). Sort it and Count it have a file each.
//
//  Each screen owns only its touch state. Which answer is right, what Penny
//  says, the glow, the star arithmetic and sending a missed question back later
//  in the lesson are all the engine's job (`LessonRunner`).
//

import SwiftUI

// MARK: - Tap to choose

/// Answer a question with big picture buttons (2 to 3 choices).
struct TapToChooseScreenView: View {
    let screen: TapToChooseScreen
    @ObservedObject var runner: LessonRunner

    @State private var chosen: String?

    var body: some View {
        VStack(spacing: 20) {
            LessonPennyHeader(mood: runner.pennyMood, line: runner.pennyLine)
            LessonPrompt(text: runner.fill(screen.prompt))

            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(screen.choices.enumerated()), id: \.element.id) { index, choice in
                    AnswerCard(icon: choice.icon,
                               label: choice.label,
                               result: result(for: choice),
                               wobble: runner.outcome == .wrong && chosen == choice.id) {
                        pick(choice)
                    }
                    .arrives(index: index)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 20)
        .onChange(of: runner.outcome) { _, outcome in
            // The glow has faded: clear the picked state so the child can retry.
            if outcome == nil { chosen = nil }
        }
        .onAppear(perform: applyUITestFeedback)
    }

    private func pick(_ choice: TapToChooseScreen.Choice) {
        guard !runner.canAdvance else { return }   // already answered correctly
        chosen = choice.id
        if choice.correct {
            runner.right(message: screen.rightMessage)
        } else {
            runner.wrong(message: screen.wrongMessage)
        }
    }

    private func result(for choice: TapToChooseScreen.Choice) -> AnswerCard.Result {
        guard chosen == choice.id else { return .normal }
        switch runner.outcome {
        case .right: return .correct
        case .wrong: return .tryAgain
        case nil:    return .normal
        }
    }

    private func applyUITestFeedback() {
        switch runner.takeUITestFeedback() {
        case "right": if let choice = screen.choices.first(where: \.correct) { pick(choice) }
        case "wrong": if let choice = screen.choices.first(where: { !$0.correct }) { pick(choice) }
        default: break
        }
    }
}

// MARK: - Story choice

/// Help a character decide what to do with their coins. Every option says what
/// happens next, so a wrong choice teaches instead of just being wrong.
struct StoryChoiceScreenView: View {
    let screen: StoryChoiceScreen
    @ObservedObject var runner: LessonRunner

    @State private var chosen: String?

    var body: some View {
        VStack(spacing: 18) {
            LessonPennyHeader(mood: runner.pennyMood, line: runner.pennyLine, pennySize: 96)

            storyCard

            LessonPrompt(text: runner.fill(screen.prompt))

            VStack(spacing: 12) {
                ForEach(screen.options) { option in
                    StoryOptionRow(option: option,
                                   result: result(for: option),
                                   wobble: runner.outcome == .wrong && chosen == option.id) {
                        pick(option)
                    }
                }
            }
            .padding(.horizontal, 20)

            if let outcome = chosenOutcome {
                Text(runner.fill(outcome))
                    .font(.rowSub)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.horizontal, 28)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(.top, 18)
        .onChange(of: runner.outcome) { _, outcome in
            if outcome == nil { chosen = nil }
        }
        .onAppear(perform: applyUITestFeedback)
    }

    /// The situation, shown as a picture and a couple of short sentences.
    private var storyCard: some View {
        HStack(spacing: 14) {
            if let icon = screen.storyIcon {
                FluentIcon(name: icon, size: 52)
            }
            Text(runner.fill(screen.story))
                .font(.rowTitle)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                .stroke(Palette.borderField, lineWidth: Border.field)
        )
        .padding(.horizontal, 20)
    }

    private var chosenOutcome: String? {
        guard let chosen, runner.outcome != nil else { return nil }
        return screen.options.first { $0.id == chosen }?.outcome
    }

    private func pick(_ option: StoryChoiceScreen.Option) {
        guard !runner.canAdvance else { return }
        chosen = option.id
        if option.correct {
            runner.right(message: screen.rightMessage)
        } else {
            runner.wrong(message: screen.wrongMessage)
        }
    }

    private func result(for option: StoryChoiceScreen.Option) -> AnswerCard.Result {
        guard chosen == option.id else { return .normal }
        switch runner.outcome {
        case .right: return .correct
        case .wrong: return .tryAgain
        case nil:    return .normal
        }
    }

    private func applyUITestFeedback() {
        switch runner.takeUITestFeedback() {
        case "right": if let option = screen.options.first(where: \.correct) { pick(option) }
        case "wrong": if let option = screen.options.first(where: { !$0.correct }) { pick(option) }
        default: break
        }
    }
}

/// One story option: a picture, what it does, and the check or hint badge.
/// A row rather than a card, because these labels are sentences.
private struct StoryOptionRow: View {
    let option: StoryChoiceScreen.Option
    let result: AnswerCard.Result
    let wobble: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                FluentIcon(name: option.icon, size: 40)
                Text(option.label)
                    .font(.buttonLabel)
                    .foregroundStyle(Palette.textBody)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                switch result {
                case .correct:  FluentIcon(name: "check-mark", size: 26)
                case .tryAgain: FluentIcon(name: "light-bulb", size: 26)
                case .normal:   Color.clear.frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
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
        .accessibilityLabel(option.label)
        .accessibilityValue(result == .correct ? "Correct" : (result == .tryAgain ? "Try again" : ""))
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
}
