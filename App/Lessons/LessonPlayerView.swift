//
//  LessonPlayerView.swift
//  Screen 4: the lesson player. One view plays ANY lesson in App/Content —
//  there are no hand-written lesson screens any more.
//
//  It draws the shared chrome (top bar, the full-screen answer glow, the coin
//  burst) and hands the current screen to the renderer for its type. The rules
//  live in `LessonRunner`; the seven screen types are README section 3:
//
//      Hello · Learn · Tap to choose · Sort it · Story choice · Count it · Yay!
//
//  Right answer  : soft green full-screen glow, the answer pops, coins and
//                  sparkles burst, a light haptic, Penny cheers.
//  Wrong answer  : warm apricot glow, a gentle wobble, a hint light bulb, Penny
//                  curls up then peeks out, and the question comes back later.
//                  NEVER a red X, a buzzer or a lost life (README section 3).
//  Reduce Motion : glows and messages fade; nothing bounces, wobbles or flies.
//

import SwiftUI

struct LessonPlayerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var runner: LessonRunner

    init(lesson: Lesson, kidName: String, startScreen: String? = nil, testFeedback: String? = nil) {
        _runner = StateObject(wrappedValue: LessonRunner(lesson: lesson,
                                                        kidName: kidName,
                                                        startScreen: startScreen,
                                                        testFeedback: testFeedback))
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                if showsTopBar {
                    LessonTopBar(title: runner.topBarTitle,
                                 isSample: runner.lesson.isSample) { app.leaveLesson() }
                }
                screenBody
                footer
            }
            .lessonContentWidth()

            // The glow sits above the content and never blocks a tap.
            if let outcome = runner.outcome {
                AnswerGlow(kind: outcome == .right ? .right : .wrong)
                    .transition(.opacity)
            }
            CoinBurst(isActive: runner.burst).allowsHitTesting(false)
        }
        .animation(reduceMotion ? .easeInOut(duration: Motion.step) : .spring(duration: Motion.step),
                   value: runner.position)
        .animation(.easeInOut(duration: Motion.glow), value: runner.outcome)
        .onAppear { runner.prefersReducedMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, new in runner.prefersReducedMotion = new }
    }

    /// The Yay! screen is a celebration, so it drops the chrome.
    private var showsTopBar: Bool {
        if case .yay = runner.screen { return false }
        return runner.screen != nil
    }

    // MARK: - The current screen

    @ViewBuilder
    private var screenBody: some View {
        switch runner.screen {
        case .hello(let screen):
            helloScreen(screen)
        case .learn(let screen):
            learnScreen(screen)
        case .tapToChoose(let screen):
            TapToChooseScreenView(screen: screen, runner: runner)
        case .sortIt(let screen):
            SortItScreenView(screen: screen, runner: runner)
        case .storyChoice(let screen):
            StoryChoiceScreenView(screen: screen, runner: runner)
        case .countIt(let screen):
            CountItScreenView(screen: screen, runner: runner)
        case .yay(let screen):
            YayScreenView(screen: screen, runner: runner)
        case nil:
            // Ran off the end (only reachable if content changed under us).
            Color.clear.onAppear { app.leaveLesson() }
        }
    }

    // MARK: Hello

    /// Penny greets the child BY NAME and says the one goal of the lesson.
    private func helloScreen(_ screen: HelloScreen) -> some View {
        VStack(spacing: 26) {
            Spacer()
            PennyView(mood: runner.pennyMood, size: 180)
            SpeechBubble(text: runner.pennyLine)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: Learn

    /// One idea, pictures first and very few words.
    private func learnScreen(_ screen: LearnScreen) -> some View {
        VStack(spacing: 22) {
            Text(runner.fill(screen.title))
                .font(.screenTitle).foregroundStyle(Palette.textHeading)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 16) {
                ForEach(screen.cards) { card in
                    ConceptCard(icon: card.icon,
                                badge: card.badge,
                                badgeColor: card.tint.color,
                                caption: runner.fill(card.caption))
                }
            }
            .padding(.horizontal, 20)

            if !runner.pennyLine.isEmpty {
                SpeechBubble(text: runner.pennyLine).padding(.horizontal, 24)
            }
            PennyView(mood: .idle, size: 110)
            Spacer()
        }
        .padding(.top, 22)
    }

    // MARK: Footer

    /// One button, one job: leave this screen. The Yay! screen brings its own.
    @ViewBuilder
    private var footer: some View {
        if runner.canAdvance, let screen = runner.screen, !screen.isYay {
            Button(runner.continueLabel) { runner.advance() }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

}

extension LessonScreen {
    var isYay: Bool {
        if case .yay = self { return true }
        return false
    }
}

// MARK: - Yay!

/// Celebration, stars, play coins and the streak (README section 3). Progress is
/// saved the moment this screen appears, so a child who closes the app on the
/// confetti still keeps what they earned.
private struct YayScreenView: View {
    let screen: YayScreen
    @ObservedObject var runner: LessonRunner
    @EnvironmentObject private var app: AppState
    @State private var saved = false
    /// Penny's scales earned by this lesson — non-zero only when it finished the
    /// whole level (README section 3, "Finishing a level adds new shiny scales").
    @State private var scalesEarned = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            // Penny and the child, cheering together. The child's own avatar is
            // here because this is the moment worth seeing yourself in.
            HStack(spacing: 4) {
                PennyView(mood: .celebrate, size: 170)
                if let kid = app.selectedKid {
                    AvatarBadge(avatar: kid.avatar, size: 84, spokenName: kid.name)
                        .padding(.bottom, 12)
                }
            }
            Text(runner.fill(screen.title))
                .font(.screenTitle).foregroundStyle(Palette.textHeading)
                .multilineTextAlignment(.center)
            StarRow(earned: runner.stars, size: 40)
            HStack(spacing: 12) {
                RewardChip(icon: "coin", value: "+\(runner.coins)", tint: Palette.copper)
                // The streak icon is a coin, never a flame.
                RewardChip(icon: "coin", value: "\(streak)-day", tint: Palette.teal)
            }
            Text(runner.fill(screen.message))
                .font(.title3).foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Finishing the level's last lesson gives Penny new scales.
            if scalesEarned > 0 {
                VStack(spacing: 8) {
                    ScaleRow(scales: scalesEarned)
                    Text(PennyScales.justEarnedLine(scales: scalesEarned, name: runner.kidName))
                        .font(.rowTitle).foregroundStyle(Palette.textBody)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            Spacer()
            Button("Back to the map") { app.leaveLesson() }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .overlay(CoinBurst(isActive: true).allowsHitTesting(false))
        .onAppear(perform: save)
    }

    private var streak: Int { app.selectedKid?.currentStreak ?? 1 }

    /// Write stars, coins, the streak day and the minutes spent — once.
    private func save() {
        guard !saved else { return }
        saved = true
        Haptics.success()
        LessonAudio.play(.celebrate)
        scalesEarned = app.completeLesson(lessonID: runner.lesson.id,
                                          stars: runner.stars,
                                          coins: runner.coins,
                                          minutes: runner.minutesSpent)
    }
}

#if DEBUG
#Preview("Needs & Wants") {
    let app = AppState.preview()
    return Group {
        if let lesson = app.library.lesson("needs-and-wants-1") {
            LessonPlayerView(lesson: lesson, kidName: "Mia").environmentObject(app)
        } else {
            Text("Content not loaded")
        }
    }
}

#Preview("Sample screen types") {
    let app = AppState.preview()
    return Group {
        if let lesson = app.library.lesson("sample-screen-types") {
            LessonPlayerView(lesson: lesson, kidName: "Mia").environmentObject(app)
        } else {
            Text("Content not loaded")
        }
    }
}
#endif
