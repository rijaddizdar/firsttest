//
//  LevelCheck.swift
//  The friendly end-of-level check from README section 3: "A friendly level
//  check at the end of each level mixes questions from its lessons. It isn't a
//  test anyone can fail. Kids simply retry questions until they get them."
//
//  The check is BUILT, not written. It is a `Lesson` like any other — so the
//  existing player, the existing retry-until-right rules and the existing
//  "stars and coins" saving all apply unchanged — but its question screens are
//  borrowed from the level's own lessons rather than typed out a second time.
//  That means a writer who rewords a question fixes the check in the same edit,
//  and a level can never drift out of sync with its own check.
//
//  Why it cannot be failed: nothing here scores or gates. `LessonRunner`
//  already refuses to advance until an answer is right and sends a missed
//  question back later, and stars never drop below 1. The check simply reuses
//  that. There is no pass mark anywhere in the app.
//

import Foundation

extension CurriculumLibrary {

    /// The id of a level's check. Stable, so a finished check stays finished
    /// across launches and shows up in saved progress like any lesson.
    static func levelCheckID(forLevel levelID: Int) -> String { "level-\(levelID)-check" }

    /// How many questions a check asks. Short on purpose: the check is a warm
    /// lap of honour, not an exam, and it has to stay inside the 3–5 minutes a
    /// lesson gets (README section 3).
    static let levelCheckQuestionCount = 4

    /// The check for a level, or nil when the level has no lessons written yet
    /// (a "Coming soon" level has nothing to check).
    func levelCheck(forLevel levelID: Int) -> Lesson? {
        guard let level = level(levelID) else { return nil }
        let lessons = lessons(inLevel: levelID)
        guard !lessons.isEmpty else { return nil }

        let questions = Self.mixedQuestions(from: lessons,
                                            limit: Self.levelCheckQuestionCount)
        guard !questions.isEmpty else { return nil }

        let hello = HelloScreen(
            id: "hello",
            penny: "Nice work on \(level.title), {name}! Let's try a few again together.",
            pose: .cheer,
            continueLabel: "I'm ready"
        )
        let yay = YayScreen(
            id: "yay",
            title: "Level finished, {name}!",
            message: "You tried every question until you got it. That's how learning works."
        )

        return Lesson(id: Self.levelCheckID(forLevel: levelID),
                      levelID: levelID,
                      title: "\(level.title) Check",
                      isSample: false,
                      isLevelCheck: true,
                      estimatedMinutes: 3,
                      coins: 15,
                      screens: [.hello(hello)] + questions + [.yay(yay)])
    }

    /// Pick the check's questions: one from each lesson in turn, then a second
    /// from each, until the limit is reached. Spreading across lessons first is
    /// what makes it a level check rather than a re-run of one lesson.
    ///
    /// Deliberately NOT shuffled. A child who comes back to a check they left
    /// half-finished should meet the same questions, and a deterministic mix is
    /// something a reviewer and a test can both read.
    ///
    /// Screen ids are rewritten to `<lesson id>/<screen id>`, because two
    /// lessons may each have a question called "q1" and the retry queue keys on
    /// the id.
    static func mixedQuestions(from lessons: [Lesson], limit: Int) -> [LessonScreen] {
        let pools = lessons.map { lesson in
            lesson.questionScreens.map { $0.withID("\(lesson.id)/\($0.id)") }
        }
        var mixed: [LessonScreen] = []
        var round = 0
        while mixed.count < limit, pools.contains(where: { round < $0.count }) {
            for pool in pools where round < pool.count {
                mixed.append(pool[round])
                if mixed.count == limit { break }
            }
            round += 1
        }
        return mixed
    }
}

// MARK: - Rewriting a borrowed screen's id

extension LessonScreen {
    /// The same screen under a new id. Used only to namespace a question the
    /// level check borrows from a lesson, so ids stay unique inside the check.
    func withID(_ newID: String) -> LessonScreen {
        switch self {
        case .hello(var s):       s.id = newID; return .hello(s)
        case .learn(var s):       s.id = newID; return .learn(s)
        case .tapToChoose(var s): s.id = newID; return .tapToChoose(s)
        case .sortIt(var s):      s.id = newID; return .sortIt(s)
        case .storyChoice(var s): s.id = newID; return .storyChoice(s)
        case .countIt(var s):     s.id = newID; return .countIt(s)
        case .yay(var s):         s.id = newID; return .yay(s)
        }
    }
}
