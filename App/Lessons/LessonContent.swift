//
//  LessonContent.swift
//  The lesson content schema: the Swift side of the bundled JSON in App/Content.
//
//  Lessons are DATA, not screens (README section 8: "Lesson content as data files
//  … writers can add lessons without changing app code"). The shapes here map
//  1:1 onto the JSON, and every screen type in README section 3 has a case in
//  `LessonScreen`. Decoding is strict and the errors name the file, the screen
//  index and the field, because a typo in a lesson file must be obvious to a
//  writer who has never opened Xcode.
//
//  Adding a lesson: drop a file in App/Content/lessons and list its id under a
//  level in App/Content/curriculum.json. Content is a folder reference in the
//  Xcode project, so no `xcodegen generate` and no Swift change is needed.
//

import SwiftUI

// MARK: - Curriculum (worlds and levels)

/// The whole level map, as read from Content/curriculum.json.
struct Curriculum: Decodable {
    let schemaVersion: Int
    let worlds: [WorldSpec]

    /// The schema version this build understands. Bump it (and migrate) only if
    /// a change is not backwards compatible.
    static let supportedSchemaVersion = 1

    var levels: [LevelSpec] { worlds.flatMap(\.levels) }
}

struct WorldSpec: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let levels: [LevelSpec]
}

/// One level on the map. `lessons` holds lesson ids in play order; empty means
/// "not written yet" — the map shows it unlocked but "Coming soon", and it does
/// not block later levels.
struct LevelSpec: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let kidSummary: String
    let icon: String
    let lessons: [String]

    var hasLessons: Bool { !lessons.isEmpty }
}

// MARK: - Lesson

/// One lesson: 3–5 minutes, one small idea, 6–8 screens (README section 3).
struct Lesson: Identifiable, Hashable {
    let id: String
    let levelID: Int
    let title: String
    /// Sample/scaffold content rather than real teaching material. The player
    /// labels it so nobody mistakes it for a written World 1 lesson.
    let isSample: Bool
    /// True for the friendly end-of-level check (README section 3), which is
    /// built from the level's own questions rather than written as a file — see
    /// `CurriculumLibrary.levelCheck(forLevel:)`.
    var isLevelCheck: Bool = false
    let estimatedMinutes: Int
    /// Play coins awarded for finishing (README section 3 rewards table).
    let coins: Int
    let screens: [LessonScreen]

    /// Screens a child actually answers — what "Question 2 of 3" counts.
    var questionScreens: [LessonScreen] { screens.filter(\.isQuestion) }
}

// MARK: - Screens

/// Every screen type in README section 3, in one enum. The JSON `"type"` field
/// selects the case.
enum LessonScreen: Identifiable, Hashable {
    case hello(HelloScreen)
    case learn(LearnScreen)
    case tapToChoose(TapToChooseScreen)
    case sortIt(SortItScreen)
    case storyChoice(StoryChoiceScreen)
    case countIt(CountItScreen)
    case yay(YayScreen)

    var id: String {
        switch self {
        case .hello(let s):       return s.id
        case .learn(let s):       return s.id
        case .tapToChoose(let s): return s.id
        case .sortIt(let s):      return s.id
        case .storyChoice(let s): return s.id
        case .countIt(let s):     return s.id
        case .yay(let s):         return s.id
        }
    }

    /// True for the screens a child answers, so they can be counted, scored and
    /// queued to come back after a wrong answer.
    var isQuestion: Bool {
        switch self {
        case .tapToChoose, .sortIt, .storyChoice, .countIt: return true
        case .hello, .learn, .yay:                          return false
        }
    }

    /// Penny's line the second time a question is asked (README section 3: a
    /// wrongly answered question "comes back later in the lesson").
    var retryIntro: String? {
        switch self {
        case .tapToChoose(let s): return s.retryIntro
        case .sortIt(let s):      return s.retryIntro
        case .storyChoice(let s): return s.retryIntro
        case .countIt(let s):     return s.retryIntro
        default:                  return nil
        }
    }

    /// Every line of this screen a child reads or hears. Used to hold the copy
    /// to the README section 7 tone rules in one place, in tests and in review.
    var kidFacingText: [String] {
        switch self {
        case .hello(let s):
            return [s.penny, s.continueLabel]
        case .learn(let s):
            return [s.title, s.continueLabel] + s.cards.map(\.caption) + s.cards.map(\.badge)
                + [s.penny].compactMap { $0 }
        case .tapToChoose(let s):
            return [s.prompt, s.pennyHint, s.rightMessage, s.wrongMessage]
                + s.choices.map(\.label) + [s.retryIntro].compactMap { $0 }
        case .sortIt(let s):
            return [s.prompt, s.pennyHint, s.rightMessage, s.wrongMessage, s.doneMessage]
                + s.groups.map(\.title) + s.items.map(\.label) + [s.retryIntro].compactMap { $0 }
        case .storyChoice(let s):
            return [s.story, s.prompt, s.pennyHint, s.rightMessage, s.wrongMessage]
                + s.options.map(\.label) + s.options.map(\.outcome) + [s.retryIntro].compactMap { $0 }
        case .countIt(let s):
            return [s.prompt, s.pennyHint, s.jarLabel, s.checkLabel, s.rightMessage, s.wrongMessage]
                + [s.retryIntro].compactMap { $0 }
        case .yay(let s):
            return [s.title, s.message]
        }
    }

    /// The "good try" line this screen shows for a wrong answer, if it has one.
    var wrongMessageText: String? {
        switch self {
        case .tapToChoose(let s): return s.wrongMessage
        case .sortIt(let s):      return s.wrongMessage
        case .storyChoice(let s): return s.wrongMessage
        case .countIt(let s):     return s.wrongMessage
        default:                  return nil
        }
    }

    /// Every icon this screen draws, so the loader can check the art exists.
    var iconNames: [String] {
        switch self {
        case .hello:              return []
        case .learn(let s):       return s.cards.map(\.icon)
        case .tapToChoose(let s): return s.choices.map(\.icon)
        case .sortIt(let s):      return s.items.map(\.icon) + s.groups.compactMap(\.icon)
        case .storyChoice(let s): return s.options.map(\.icon) + [s.storyIcon].compactMap { $0 }
        case .countIt(let s):     return [s.jarIcon, "coin"]
        case .yay:                return []
        }
    }
}

/// Penny greets the child by name and says the one goal of the lesson.
struct HelloScreen: Hashable {
    var id: String
    let penny: String
    let pose: PennyPose
    let continueLabel: String
}

/// One idea, pictures first and very few words.
struct LearnScreen: Hashable {
    var id: String
    let title: String
    let cards: [LearnCard]
    let penny: String?
    let continueLabel: String

    struct LearnCard: Decodable, Hashable, Identifiable {
        var id: String { icon + badge }
        let icon: String
        let badge: String
        let tint: ContentTint
        let caption: String
    }
}

/// Answer a question with big picture buttons (2 to 3 choices).
struct TapToChooseScreen: Hashable {
    var id: String
    let prompt: String
    let pennyHint: String
    let choices: [Choice]
    let rightMessage: String
    let wrongMessage: String
    let retryIntro: String?

    struct Choice: Decodable, Hashable, Identifiable {
        var id: String { label }
        let label: String
        let icon: String
        let correct: Bool

        private enum CodingKeys: String, CodingKey { case label, icon, correct }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            label = try c.decode(String.self, forKey: .label)
            icon = try c.decode(String.self, forKey: .icon)
            correct = try c.decodeIfPresent(Bool.self, forKey: .correct) ?? false
        }
    }
}

/// Drag pictures into groups, like "Need" and "Want".
struct SortItScreen: Hashable {
    /// The tray is a single row of picture chips, so this is what fits across a
    /// phone. Enforced when content loads.
    static let maxItems = 4

    var id: String
    let prompt: String
    let pennyHint: String
    let groups: [Group]
    let items: [Item]
    let rightMessage: String
    let wrongMessage: String
    /// Penny's line once every picture is sorted.
    let doneMessage: String
    let retryIntro: String?

    struct Group: Decodable, Hashable, Identifiable {
        let id: String
        let title: String
        let icon: String?
        let tint: ContentTint
    }

    struct Item: Decodable, Hashable, Identifiable {
        let id: String
        let label: String
        let icon: String
        /// The group this picture belongs in.
        let groupID: String
    }
}

/// Help a character decide what to do with their coins.
struct StoryChoiceScreen: Hashable {
    var id: String
    let story: String
    let storyIcon: String?
    let prompt: String
    let pennyHint: String
    let options: [Option]
    let rightMessage: String
    let wrongMessage: String
    let retryIntro: String?

    struct Option: Decodable, Hashable, Identifiable {
        var id: String { label }
        let label: String
        let icon: String
        let correct: Bool
        /// What happens in the story if this choice is taken — shown after the
        /// tap, so a wrong choice teaches instead of just being wrong.
        let outcome: String

        private enum CodingKeys: String, CodingKey { case label, icon, correct, outcome }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            label = try c.decode(String.self, forKey: .label)
            icon = try c.decode(String.self, forKey: .icon)
            correct = try c.decodeIfPresent(Bool.self, forKey: .correct) ?? false
            outcome = try c.decode(String.self, forKey: .outcome)
        }
    }
}

/// Add or split play coins using kid-sized numbers (README section 7 rule 8:
/// whole numbers, play coins, never real prices).
struct CountItScreen: Hashable {
    /// The pile of coins is a single row, so this is what fits across a phone.
    /// Enforced when content loads.
    static let maxAvailable = 8

    var id: String
    let prompt: String
    let pennyHint: String
    /// How many coins the child has to work with.
    let available: Int
    /// How many belong in the jar.
    let target: Int
    let jarIcon: String
    let jarLabel: String
    let checkLabel: String
    let rightMessage: String
    let wrongMessage: String
    let retryIntro: String?
}

/// Celebration, stars, play coins and the streak.
struct YayScreen: Hashable {
    var id: String
    let title: String
    let message: String
}

// MARK: - Tints

/// The only colours lesson content may name. Writers can't invent a colour, so
/// the Penny Design System palette stays closed (and never red).
enum ContentTint: String, Decodable {
    case teal, copper, skyTeal, star, peach

    var color: Color {
        switch self {
        case .teal:    return Palette.teal
        case .copper:  return Palette.copper
        case .skyTeal: return Palette.skyTeal
        case .star:    return Palette.star
        case .peach:   return Palette.peach
        }
    }
}

// MARK: - Penny poses in content

/// The poses a lesson file may ask Penny for, mapped onto `PennyMood`.
enum PennyPose: String, Decodable {
    case idle, wave, cheer, celebrate, encourage, curl

    var mood: PennyMood {
        switch self {
        case .idle:      return .idle
        case .wave:      return .wave
        case .cheer:     return .cheer
        case .celebrate: return .celebrate
        case .encourage: return .encourage
        case .curl:      return .curl
        }
    }
}
