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
    /// Penny's shiny scales — three per level finished (see `PennyScales`).
    var pennyScales: Int = 0
    /// Shop items bought with play coins, by content id (`Content/shop.json`).
    var ownedItemIDs: Set<String> = []
    /// The scarf colour Penny wears for this child. Nil means her own colour.
    var pennyScarfItemID: String?

    // Parent-dashboard figures (README section 6), from the day records.
    var minutesToday: Int = 0
    var minutesThisWeek: Int = 0
    /// Minutes per day for every day still kept, newest day last. README
    /// section 9 keeps this on a rolling window only, so this is at most the
    /// last `ProgressStore.usageRetentionDays` days.
    var dailyMinutes: [DayMinutes] = []

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

    /// Minutes per day for the last `days` days, oldest first, with zero-minute
    /// days filled in — the shape the dashboard's day bars want. Days outside
    /// the retention window simply come back as zero.
    func minutesPerDay(lastDays days: Int, endingOn today: Date = Date(),
                       calendar: Calendar = .current) -> [DayMinutes] {
        let end = calendar.startOfDay(for: today)
        var byDay: [Date: Int] = [:]
        for entry in dailyMinutes { byDay[calendar.startOfDay(for: entry.day), default: 0] += entry.minutes }
        return (0..<max(1, days)).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: end) else { return nil }
            return DayMinutes(day: day, minutes: byDay[day] ?? 0)
        }
    }

    // MARK: Rewards

    /// Has this child bought this shop item?
    func owns(_ itemID: String) -> Bool { ownedItemIDs.contains(itemID) }

    /// The item id this child has chosen for a worn kind, if they have chosen
    /// one. Nil means "whatever the shop's default is" — `ShopLibrary` resolves
    /// that, because only it knows the catalog. Stickers are collected rather
    /// than worn, so they always answer nil.
    func chosenItemID(for kind: ShopItemKind) -> String? {
        switch kind {
        case .sticker:    return nil
        case .pennyScarf: return pennyScarfItemID
        }
    }
}

/// Minutes a child spent on one day. The parent dashboard's "time spent"
/// (README section 6) and the daily limit both read these.
struct DayMinutes: Identifiable, Equatable {
    /// Midnight of the day.
    let day: Date
    let minutes: Int
    var id: Date { day }
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
    /// How long a child may learn each day, or `ParentSettings.noDailyLimit`
    /// (0) for no limit at all. One setting for the whole family for now: the
    /// store holds a single value (README section 6 wants it per child — that
    /// needs a field on `KidRecord`).
    var dailyLimitMinutes: Int = 20
    var soundOn: Bool = true

    /// The value that means "no limit". Grown-ups who don't want a cap pick it.
    static let noDailyLimit = 0
    /// The choices the dashboard offers, in minutes; `noDailyLimit` first.
    static let dailyLimitChoices = [noDailyLimit, 10, 15, 20, 30, 45, 60, 90]

    var hasDailyLimit: Bool { dailyLimitMinutes > 0 }

    /// How the limit reads in the grown-up area.
    var dailyLimitLabel: String {
        hasDailyLimit ? "\(dailyLimitMinutes) min" : "No limit"
    }
    /// How many digits the stored parent code has, so the keypad knows when to
    /// submit. Nil when no code is set. The code itself is only ever stored as a
    /// salted hash (README section 9).
    var parentCodeDigits: Int?
}
