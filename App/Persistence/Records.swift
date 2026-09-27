//
//  Records.swift
//  The SwiftData models — everything the app remembers between launches
//  (README section 8: "SwiftData for offline progress").
//
//  ON-DEVICE ONLY. There is no backend and no sync yet, so nothing here leaves
//  the device. The fields are deliberately limited to the data README section 9
//  allows for a child: a first name or nickname, avatar choices, lesson progress,
//  stars, play coins, streaks, and time spent per day. No last names, no
//  birthdays, no photos, no free text, no identifiers of any kind.
//
//  The parent code is stored ONLY as a salted SHA-256 hash, never in plain text
//  (README section 9, last row of the table).
//

import Foundation
import SwiftData

/// One child profile and their progress.
@Model
final class KidRecord {
    /// Stable id so the app's view models and the store agree on who is who.
    @Attribute(.unique) var id: UUID
    /// First name or nickname only.
    var name: String
    /// `AvatarKind.rawValue` ("boy" / "girl").
    var avatarKindRaw: String
    var avatarColorIndex: Int

    var coins: Int
    var currentStreak: Int
    var bestStreak: Int
    /// The day (midnight) of the last finished lesson, for streak counting.
    var lastFinishedDay: Date?
    /// Profile order on "Who's learning?".
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LessonResultRecord.kid)
    var lessonResults: [LessonResultRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyUsageRecord.kid)
    var dailyUsage: [DailyUsageRecord] = []

    init(id: UUID = UUID(),
         name: String,
         avatarKindRaw: String,
         avatarColorIndex: Int,
         coins: Int = 0,
         currentStreak: Int = 0,
         bestStreak: Int = 0,
         lastFinishedDay: Date? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.avatarKindRaw = avatarKindRaw
        self.avatarColorIndex = avatarColorIndex
        self.coins = coins
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastFinishedDay = lastFinishedDay
        self.createdAt = createdAt
    }
}

/// One finished lesson. Kept per lesson, not per level, so replaying a lesson
/// can improve its stars (README section 3) and a level's rating is derived.
@Model
final class LessonResultRecord {
    /// The lesson's content id, e.g. "needs-and-wants-1".
    var lessonID: String
    var levelID: Int
    /// Best result so far, 1...3.
    var stars: Int
    var completedAt: Date
    var timesPlayed: Int
    var kid: KidRecord?

    init(lessonID: String, levelID: Int, stars: Int, completedAt: Date = Date(), timesPlayed: Int = 1) {
        self.lessonID = lessonID
        self.levelID = levelID
        self.stars = stars
        self.completedAt = completedAt
        self.timesPlayed = timesPlayed
    }
}

/// Minutes spent on a single day, for the parent dashboard and the daily limit.
/// README section 9 keeps this on a rolling window only: `ProgressStore` prunes
/// anything older than 90 days at launch.
@Model
final class DailyUsageRecord {
    /// Midnight of the day these minutes belong to.
    var day: Date
    var minutes: Int
    var kid: KidRecord?

    init(day: Date, minutes: Int) {
        self.day = day
        self.minutes = minutes
    }
}

/// The single settings row: the parent code (hashed) and the grown-up controls.
@Model
final class SettingsRecord {
    /// Salted SHA-256 of the parent code. Nil until a grown-up sets one.
    var parentCodeHash: String?
    /// Random per-install salt, so the hash can't be looked up in a table.
    var parentCodeSalt: String?
    /// How many digits the code has, so the keypad knows when to submit. The
    /// digits themselves are never stored.
    var parentCodeDigits: Int
    var dailyLimitMinutes: Int
    var soundOn: Bool

    init(parentCodeHash: String? = nil,
         parentCodeSalt: String? = nil,
         parentCodeDigits: Int = 0,
         dailyLimitMinutes: Int = 20,
         soundOn: Bool = true) {
        self.parentCodeHash = parentCodeHash
        self.parentCodeSalt = parentCodeSalt
        self.parentCodeDigits = parentCodeDigits
        self.dailyLimitMinutes = dailyLimitMinutes
        self.soundOn = soundOn
    }
}

/// Everything the app persists, in one place for the container.
enum PersistedSchema {
    static let models: [any PersistentModel.Type] = [
        KidRecord.self, LessonResultRecord.self, DailyUsageRecord.self, SettingsRecord.self
    ]
}
