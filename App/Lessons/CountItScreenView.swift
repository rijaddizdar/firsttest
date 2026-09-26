//
//  CountItScreenView.swift
//  "Count it" (README section 3): add or split play coins using kid-sized
//  numbers (README section 7 rule 8 — whole coins, never real prices).
//
//  The child taps coins from the pile into the jar, counts what's in there, and
//  taps Check. The jar shows the coins as pictures AND the number, so a child
//  who can't read the numeral can still count the coins.
//

import SwiftUI

struct CountItScreenView: View {
    let screen: CountItScreen
    @ObservedObject var runner: LessonRunner

    /// How many coins are in the jar right now.
    @State private var inJar = 0
    /// Set after a wrong check, so the jar wobbles once.
    @State private var wobble = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            LessonPennyHeader(mood: runner.pennyMood, line: runner.pennyLine, pennySize: 88)
            LessonPrompt(text: runner.fill(screen.prompt))

            jar
            pile

            if !runner.canAdvance {
                Button(screen.checkLabel) { check() }
                    .buttonStyle(BigButtonStyle(fill: inJar > 0 ? Palette.teal : Palette.actionDisabled))
                    .disabled(inJar == 0)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .onAppear(perform: applyUITestFeedback)
    }

    // MARK: The jar

    private var jar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                FluentIcon(name: screen.jarIcon, size: 44)
                Text(screen.jarLabel)
                    .font(.rowTitle).foregroundStyle(Palette.textBody)
                Spacer(minLength: 0)
                // The count in words as well as coins, for a child still learning
                // numerals.
                Text("\(inJar)")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textHeading)
                    .accessibilityLabel("\(inJar) coins in the jar")
            }

            // The coins themselves. Tapping one takes it back out.
            HStack(spacing: 6) {
                ForEach(0..<max(inJar, 1), id: \.self) { index in
                    if index < inJar {
                        Button { take() } label: { FluentIcon(name: "coin", size: 30) }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Take a coin out of the jar")
                    } else {
                        // Keeps the row's height while the jar is empty.
                        Color.clear.frame(width: 30, height: 30)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 34)
        }
        .padding(16)
        .background(jarFill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(jarBorder, lineWidth: Border.choice)
        )
        .rotationEffect(.degrees(wobble && !reduceMotion ? Motion.wobbleDeg : 0))
        .animation(.easeInOut(duration: Motion.press).repeatCount(3, autoreverses: true), value: wobble)
        .padding(.horizontal, 20)
    }

    // MARK: The pile

    /// The coins the child still has in hand.
    private var pile: some View {
        VStack(spacing: 8) {
            Text("Tap a coin to put it in")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
            HStack(spacing: 8) {
                ForEach(0..<screen.available, id: \.self) { index in
                    Button { put() } label: {
                        FluentIcon(name: "coin", size: 36)
                            .opacity(index < screen.available - inJar ? 1 : 0.15)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(index >= screen.available - inJar)
                    .accessibilityLabel("Put a coin in the jar")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Counting

    private func put() {
        guard !runner.canAdvance, inJar < screen.available else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: Motion.press) : .spring(duration: Motion.press)) {
            inJar += 1
        }
    }

    private func take() {
        guard !runner.canAdvance, inJar > 0 else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: Motion.press) : .spring(duration: Motion.press)) {
            inJar -= 1
        }
    }

    private func check() {
        guard !runner.canAdvance else { return }
        if inJar == screen.target {
            runner.right(message: screen.rightMessage)
        } else {
            wobble = true
            runner.wrong(message: screen.wrongMessage)
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                wobble = false
            }
        }
    }

    private var jarFill: Color {
        switch runner.outcome {
        case .right: return Palette.stateCorrectBg
        case .wrong: return Palette.stateRetryBg
        case nil:    return Palette.surfaceCard
        }
    }

    private var jarBorder: Color {
        switch runner.outcome {
        case .right: return Palette.stateCorrectBorder
        case .wrong: return Palette.stateRetryBorder
        case nil:    return Palette.borderField
        }
    }

    /// Screenshots: fill the jar right, or one coin short, and check it.
    private func applyUITestFeedback() {
        switch runner.takeUITestFeedback() {
        case "right":
            inJar = screen.target
            check()
        case "wrong":
            inJar = max(1, screen.target - 1)
            check()
        default: break
        }
    }
}
