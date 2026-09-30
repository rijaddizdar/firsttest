//
//  LessonRunner.swift
//  The lesson engine: plays a `Lesson` screen by screen and owns every rule from
//  the README section 3 answer table that isn't a pixel.
//
//  What it does:
//   • Walks the lesson's screens in order and knows which question number the
//     child is on.
//   • Right answer  -> soft-green glow, pop, coin burst, a light haptic, a happy
//     chime, Penny cheers, and the child moves on.
//   • Wrong answer  -> warm-apricot glow (never red), a gentle wobble, a hint
//     light bulb, a soft boop, no haptic, Penny curls into a ball and then peeks
//     out to help — and the question COMES BACK later in the lesson.
//   • Reduce Motion -> nothing bounces or wobbles; glows and messages fade and
//     Penny holds a still pose. (The views read the environment themselves; the
//     runner only skips Penny's curl-then-peek pose change.)
//   • Counts mistakes into stars (3 for a clean run, never fewer than 1) and how
//     long the lesson took, for the store to save.
//
//  The screen views own their own touch state; everything shared — the glow,
//  Penny's pose, her line, whether the Next button is showing — lives here.
//

import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif

@MainActor
final class LessonRunner: ObservableObject {

    /// Which answer effect is on screen, if any.
    enum Outcome: Equatable { case right, wrong }

    let lesson: Lesson
    let kidName: String

    /// Screen indices in play order. A question answered wrong is appended a
    /// second time, just before the Yay! screen.
    @Published private(set) var plan: [Int]
    @Published private(set) var position = 0

    @Published private(set) var outcome: Outcome?
    /// Penny's current line, with {name} already filled in.
    @Published private(set) var pennyLine: String
    @Published private(set) var pennyMood: PennyMood = .idle
    /// True once the child may move on (a right answer, or a screen with no question).
    @Published private(set) var canAdvance: Bool
    @Published private(set) var burst = false

    /// Every wrong tap in this run — the star arithmetic.
    private(set) var wrongTaps = 0
    /// Questions that have already been sent back to the end once.
    private var requeued: Set<String> = []
    private var pendingClear: Task<Void, Never>?
    /// A screenshot run holds the answer state on screen instead of letting it
    /// fade after a beat, so a capture can't miss it.
    private let holdsFeedback: Bool
    private var pennyPeek: Task<Void, Never>?
    private let startedAt = Date()

    /// Set by the player from the environment so the engine can skip the pose
    /// flip when Reduce Motion is on.
    var prefersReducedMotion = false

    /// Screenshot hook: the answer state the current question screen should put
    /// itself into as it appears ("right" or "wrong"). Each screen consumes it
    /// once, by playing the real answer path — so a screenshot shows exactly what
    /// a child sees. Nil in normal use.
    var uiTestFeedback: String?

    func takeUITestFeedback() -> String? {
        defer { uiTestFeedback = nil }
        return uiTestFeedback
    }

    /// `startScreen` and `testFeedback` are the screenshot hooks, applied here
    /// rather than in `onAppear` so the first frame a screen draws is already the
    /// state being captured.
    init(lesson: Lesson, kidName: String, startScreen: String? = nil, testFeedback: String? = nil) {
        self.lesson = lesson
        self.kidName = kidName
        self.plan = Array(lesson.screens.indices)
        let first = lesson.screens.first
        self.pennyLine = LessonRunner.line(for: first, kidName: kidName)
        self.canAdvance = !(first?.isQuestion ?? false)
        self.holdsFeedback = testFeedback != nil

        if testFeedback == "complete" {
            if let yay = lesson.screens.first(where: \.isYay) { jump(to: yay.id) }
            return
        }
        if let startScreen {
            jump(to: startScreen)
        } else if testFeedback != nil, let question = lesson.screens.first(where: \.isQuestion) {
            jump(to: question.id)
        }
        uiTestFeedback = testFeedback
    }

    // MARK: - Where we are

    var screen: LessonScreen? {
        guard position < plan.count, let index = plan[safe: position] else { return nil }
        return lesson.screens[safe: index]
    }

    var isFinished: Bool { position >= plan.count }

    /// This screen is a question the child already got wrong once, now back.
    var isRepeat: Bool {
        guard let screen, screen.isQuestion else { return false }
        let earlier = plan.prefix(position).compactMap { lesson.screens[safe: $0]?.id }
        return earlier.contains(screen.id)
    }

    /// "Question 2 of 4" — counts question screens only, repeats included.
    var questionNumber: Int? {
        guard let screen, screen.isQuestion else { return nil }
        let planned = plan.prefix(position + 1).compactMap { lesson.screens[safe: $0] }
        return planned.filter(\.isQuestion).count
    }

    var questionCount: Int { plan.compactMap { lesson.screens[safe: $0] }.filter(\.isQuestion).count }

    /// The title for the lesson's top bar.
    var topBarTitle: String {
        if let number = questionNumber { return "Question \(number) of \(questionCount)" }
        return lesson.title
    }

    // MARK: - Results

    /// Up to 3 stars; a clean run earns 3 and nobody ever finishes with none.
    var stars: Int { max(1, 3 - wrongTaps) }
    var coins: Int { lesson.coins }
    /// Whole minutes spent, for the parent dashboard's time figures.
    var minutesSpent: Int { max(1, Int((Date().timeIntervalSince(startedAt) / 60).rounded(.up))) }

    // MARK: - Moving on

    func advance() {
        pendingClear?.cancel()
        pennyPeek?.cancel()
        outcome = nil
        burst = false
        position += 1
        let next = screen
        pennyLine = LessonRunner.line(for: next, kidName: kidName, isRepeat: isRepeat)
        pennyMood = LessonRunner.mood(for: next)
        canAdvance = !(next?.isQuestion ?? true)
    }

    /// Label for the button that leaves the current screen.
    var continueLabel: String {
        switch screen {
        case .hello(let s): return s.continueLabel
        case .learn(let s): return s.continueLabel
        default:
            // A question: the last one finishes the lesson, the rest move on.
            let remaining = plan.count - position - 1
            return remaining <= 1 ? "Finish" : "Next"
        }
    }

    // MARK: - Answers (README section 3)

    /// A right answer. `advances` is false for a step inside a screen that isn't
    /// finished yet, like one correct drop in a Sort it.
    func right(message: String? = nil, advances: Bool = true) {
        pendingClear?.cancel()
        pennyPeek?.cancel()
        outcome = .right
        pennyMood = .cheer
        pennyLine = fill(message) ?? pennyLine
        burst = true
        canAdvance = advances
        Haptics.rightAnswerTap()          // a light tap on right, nothing on wrong
        LessonAudio.play(.right)
        if !advances {
            // Clear the glow so the rest of the screen is playable again.
            pendingClear = clearAfter(1.1)
        }
    }

    /// A wrong answer. Kind, never red, and the question comes back later.
    func wrong(message: String? = nil) {
        pendingClear?.cancel()
        pennyPeek?.cancel()
        wrongTaps += 1
        outcome = .wrong
        pennyLine = fill(message) ?? pennyLine
        burst = false
        canAdvance = false
        LessonAudio.play(.wrong)          // a soft boop, never a buzzer
        // Penny curls into a ball, then peeks out to help. Under Reduce Motion
        // she simply holds the gentle pose.
        if prefersReducedMotion {
            pennyMood = .encourage
        } else {
            pennyMood = .curl
            pennyPeek = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 550_000_000)
                guard let self, !Task.isCancelled, self.outcome == .wrong else { return }
                self.pennyMood = .encourage
            }
        }
        requeue()
        pendingClear = clearAfter(1.4)
    }

    /// Drop the answer glow so the child can try again, keeping Penny's hint up.
    private func clearAfter(_ seconds: Double) -> Task<Void, Never>? {
        guard !holdsFeedback else { return nil }
        return Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            guard !self.canAdvance else { return }
            withAnimation(.easeInOut(duration: Motion.glow)) {
                self.outcome = nil
                self.burst = false
                self.pennyMood = .idle
            }
        }
    }

    /// Send a wrongly answered question back to the end of the lesson, once.
    /// It lands just before the Yay! screen, so the lesson still ends on a
    /// celebration (README section 3: "The question comes back later").
    private func requeue() {
        guard let screen, screen.isQuestion, !requeued.contains(screen.id) else { return }
        guard let index = plan[safe: position] else { return }
        requeued.insert(screen.id)
        let insertAt = max(position + 1, plan.count - 1)   // before the Yay! screen
        plan.insert(index, at: insertAt)
    }

    // MARK: - Copy

    /// Fill {name} with the child's name — Penny always uses it (README section 7).
    func fill(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "{name}", with: kidName)
    }

    func fill(_ text: String) -> String {
        text.replacingOccurrences(of: "{name}", with: kidName)
    }

    /// Penny's pose when a screen opens: a Hello screen names one, everything
    /// else starts from her calm idle.
    private static func mood(for screen: LessonScreen?) -> PennyMood {
        guard let screen else { return .idle }
        if case .hello(let hello) = screen { return hello.pose.mood }
        return .idle
    }

    private static func line(for screen: LessonScreen?, kidName: String, isRepeat: Bool = false) -> String {
        guard let screen else { return "" }
        let fill = { (text: String) in text.replacingOccurrences(of: "{name}", with: kidName) }
        if isRepeat, screen.isQuestion {
            return fill(screen.retryIntro ?? "Here's that one again, {name}. You've got this!")
        }
        switch screen {
        case .hello(let s):       return fill(s.penny)
        case .learn(let s):       return fill(s.penny ?? "")
        case .tapToChoose(let s): return fill(s.pennyHint)
        case .sortIt(let s):      return fill(s.pennyHint)
        case .storyChoice(let s): return fill(s.pennyHint)
        case .countIt(let s):     return fill(s.pennyHint)
        case .yay(let s):         return fill(s.message)
        }
    }

    // MARK: - Screenshots / UI tests

    /// Jump to a screen by id or 1-based number, and optionally show it in a
    /// right- or wrong-answer state. Used only by the screenshot hooks.
    func jump(to identifier: String) {
        let target: Int? = lesson.screens.firstIndex { $0.id == identifier }
            ?? Int(identifier).map { $0 - 1 }
        guard let target, lesson.screens.indices.contains(target),
              let planIndex = plan.firstIndex(of: target) else { return }
        position = planIndex
        outcome = nil
        burst = false
        pennyLine = LessonRunner.line(for: screen, kidName: kidName)
        pennyMood = LessonRunner.mood(for: screen)
        canAdvance = !(screen?.isQuestion ?? true)
    }
}

// MARK: - Sound hook

/// The one place lesson sound is triggered. **Stub:** no audio assets are
/// bundled yet, so these calls do nothing — the happy chime and the soft boop
/// from README section 3 land here (AVFoundation, per README section 8) once the
/// sound design exists, together with the grown-up "sounds off" switch.
enum LessonAudio {
    enum Cue { case right, wrong, celebrate }

    /// Grown-ups can turn sound off (README section 3). `AppState` mirrors the
    /// saved setting into this on every reload.
    static var isEnabled = true

    /// Kept alive while playing — an AVAudioPlayer that goes out of scope stops
    /// mid-sound. One per cue, so a quick right-right-right never cuts itself off
    /// awkwardly and nothing is allocated on the tap.
    #if canImport(AVFoundation)
    private static var players: [String: AVAudioPlayer] = [:]
    #endif

    static func play(_ cue: Cue) {
        guard isEnabled else { return }
        #if canImport(AVFoundation)
        let name: String
        switch cue {
        case .right:     name = "right"
        case .wrong:     name = "wrong"
        case .celebrate: name = "celebrate"
        }
        guard let player = player(named: name) else { return }
        player.currentTime = 0
        player.play()
        #endif
    }

    #if canImport(AVFoundation)
    private static func player(named name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav",
                                        subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: name, withExtension: "wav") else {
            return nil          // no asset: stay silent rather than crash
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        // Lesson sounds are effects, not music: they must not stop whatever the
        // family is already listening to, and they must still be heard when the
        // ring switch is silent, like other kids' apps.
        players[name] = player
        return player
    }

    /// Set the audio session once, at launch. `.ambient` means Penny never
    /// interrupts music playing in the background.
    static func configureSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
    #else
    static func configureSession() {}
    #endif
}

// MARK: - Small helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
