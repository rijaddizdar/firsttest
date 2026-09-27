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
    /// The outfit colour — an index into `Palette.avatarChoices`.
    var avatarColorIndex: Int

    // The rest of the avatar builder's choices (README section 6
    // "Customization"). OPTIONAL on purpose: they were added after the first
    // version shipped its store, and an optional attribute is what SwiftData
    // migrates without a migration plan. A profile saved before the builder
    // existed reads back as nil here and is shown with `Avatar.defaultLook`,
    // keeping the boy/girl look and outfit colour it already had.
    /// `Hairstyle.rawValue`.
    var avatarHairstyleRaw: String?
    /// Index into `Palette.avatarSkinTones`.
    var avatarSkinToneIndex: Int?
    /// Index into `Palette.avatarHairColors` (or the scarf colours).
    var avatarHairColorIndex: Int?
    /// Whether the child has done their own first time — name, "Make it
    /// yours!", meet Penny. Nil means a profile from before that flow existed,
    /// which is treated as done: nobody who is already learning gets sent back
    /// to a welcome screen.
    var hasFinishedFirstRun: Bool?

    var coins: Int
    var currentStreak: Int
    var bestStreak: Int
    /// The day (midnight) of the last finished lesson, for streak counting.
    var lastFinishedDay: Date?
    /// Profile order on "Who's learning?".
    var createdAt: Date

    /// Penny's shiny scales — three for every level this child finishes
    /// (README section 3). A count, not artwork: see `PennyScales`.
    ///
    /// New properties on this model carry a default so an existing on-device
    /// store migrates by itself; `PersistenceController` falls back to a fresh
    /// store if one ever can't be opened, so a child is never locked out.
    var pennyScales: Int = 0

    /// Which scarf colour Penny wears, as a shop item id (`Content/shop.json`).
    /// Nil means her own colour. A customization choice, which is the only kind
    /// of extra data README section 9 allows us to keep for a child.
    var pennyScarfItemID: String?

    @Relationship(deleteRule: .cascade, inverse: \LessonResultRecord.kid)
    var lessonResults: [LessonResultRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyUsageRecord.kid)
    var dailyUsage: [DailyUsageRecord] = []

    /// Everything this child has bought with play coins.
    @Relationship(deleteRule: .cascade, inverse: \ShopPurchaseRecord.kid)
    var purchases: [ShopPurchaseRecord] = []

    init(id: UUID = UUID(),
         name: String,
         avatarKindRaw: String,
         avatarColorIndex: Int,
         avatarHairstyleRaw: String? = nil,
         avatarSkinToneIndex: Int? = nil,
         avatarHairColorIndex: Int? = nil,
         hasFinishedFirstRun: Bool? = nil,
         coins: Int = 0,
         currentStreak: Int = 0,
         bestStreak: Int = 0,
         lastFinishedDay: Date? = nil,
         createdAt: Date = Date(),
         pennyScales: Int = 0,
         pennyScarfItemID: String? = nil) {
        self.id = id
        self.name = name
        self.avatarKindRaw = avatarKindRaw
        self.avatarColorIndex = avatarColorIndex
        self.avatarHairstyleRaw = avatarHairstyleRaw
        self.avatarSkinToneIndex = avatarSkinToneIndex
        self.avatarHairColorIndex = avatarHairColorIndex
        self.hasFinishedFirstRun = hasFinishedFirstRun
        self.coins = coins
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastFinishedDay = lastFinishedDay
        self.createdAt = createdAt
        self.pennyScales = pennyScales
        self.pennyScarfItemID = pennyScarfItemID
    }
}

/// One thing a child bought with play coins: a sticker, or a colour for Penny's
/// scarf. The id is the shop item's id from `App/Content/shop.json`.
///
/// Play coins are pretend money earned by finishing lessons. Nothing here was
/// ever bought with real money, and no purchase path exists in the app
/// (README section 9, "No purchases for kids").
@Model
final class ShopPurchaseRecord {
    /// The shop item's content id, e.g. "sticker-rainbow".
    var itemID: String
    var boughtAt: Date
    var kid: KidRecord?

    init(itemID: String, boughtAt: Date = Date()) {
        self.itemID = itemID
        self.boughtAt = boughtAt
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
        KidRecord.self, LessonResultRecord.self, DailyUsageRecord.self,
        ShopPurchaseRecord.self, SettingsRecord.self
    ]
}
