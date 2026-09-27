//
//  Models.swift
//  The value types the screens work with.
//
//  `Kid` is a read-only projection of what the store holds (Persistence/) plus
//  the figures derived from the bundled content (Lessons/): which levels are
//  unlocked, what a level's star rating is. Screens render it; they never mutate
//  it. Every change goes through `AppState`, which writes to SwiftData and
//  reloads.
//
//  The level map itself is content, not code: it comes from
//  App/Content/curriculum.json (see `CurriculumLibrary`).
//

import SwiftUI

// MARK: - Kid profile

// The avatar itself — boy/girl, hairstyle, skin tone, hair colour, outfit
// colour — lives in Avatar/Avatar.swift, and is drawn by Avatar/AvatarArtwork.swift.

/// One child. Profiles belong to the parent account (README section 6).
/// All data here is the minimised set from README section 9 — name, avatar,
/// progress. No last names, birthdays, photos or free text.
struct Kid: Identifiable, Equatable {
    let id: UUID
    var name: String
    var avatar: Avatar
    /// False until the child has done their own first time — name, "Make it
    /// yours!", meet Penny (README section 6). Tapping their face on
    /// "Who's learning?" runs that flow instead of opening the map.
    var hasFinishedFirstRun: Bool = true

    // Rewards (README section 3).
    var coins: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    // Parent-dashboard figures (README section 6), from the day records.
    var minutesToday: Int = 0
    var minutesThisWeek: Int = 0

    /// Best stars per finished lesson, keyed by lesson content id.
    var starsByLesson: [String: Int] = [:]
    /// Star rating shown per level on the map — only set once a level is done.
    var starsByLevel: [Int: Int] = [:]
    /// Map state per level, derived from the content and this child's progress.
    var levelStates: [Int: LevelLockState] = [:]
    /// The level the child is working on now. Levels unlock in order.
    var unlockedThrough: Int = 1

    /// The child's outfit colour, which the rest of the UI tints their badge
    /// and chips with.
    var avatarColor: Color { avatar.outfitColor }

    /// Every star the child has actually earned — the count on the map header
    /// and in the grown-up area. It is the sum of their best result per finished
    /// LESSON, so a star shows up the moment it is won.
    ///
    /// `starsByLevel` is a different number on purpose: a level is only rated
    /// once every lesson in it is finished, so summing that would show 0 to a
    /// child who just earned three stars in the first lesson of a level.
    var totalStars: Int { starsByLesson.values.reduce(0, +) }

    /// How many lessons this child has finished at least once.
    var lessonsFinished: Int { starsByLesson.count }

    func lockState(for levelID: Int) -> LevelLockState {
        levelStates[levelID] ?? (levelID <= unlockedThrough ? .current : .locked)
    }

    func hasFinished(lessonID: String) -> Bool { starsByLesson[lessonID] != nil }
}

/// How a level shows up on the map.
///   completed  — every lesson in it finished
///   current    — the level the child is working on
///   open       — unlocked, but its lessons aren't written yet ("Coming soon")
///   locked     — earlier levels come first
enum LevelLockState {
    case completed, current, open, locked
}

// MARK: - Grown-up settings

/// Per-account parental controls (README section 6). Persisted in `SettingsRecord`.
struct ParentSettings: Equatable {
    var dailyLimitMinutes: Int = 20
    var soundOn: Bool = true
    /// How many digits the stored parent code has, so the keypad knows when to
    /// submit. Nil when no code is set. The code itself is only ever stored as a
    /// salted hash (README section 9).
    var parentCodeDigits: Int?
}
