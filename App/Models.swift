//
//  Models.swift
//  Plain in-memory model types + sample data for the mock-up.
//
//  This is a scaffold: no SwiftData, no backend, no networking. Everything lives
//  in memory for the duration of the run. The real app would persist progress in
//  SwiftData and sync to a first-party backend (README.md section 8).
//

import SwiftUI

// MARK: - Kid profile

enum AvatarKind: String, CaseIterable, Identifiable {
    case boy, girl
    var id: String { rawValue }

    /// SF Symbol placeholder for the boy/girl avatar look (README section 6).
    var symbolName: String { self == .boy ? "figure.child" : "figure.child.circle" }
    var label: String { self == .boy ? "Boy" : "Girl" }
}

/// One child. Profiles belong to the parent account (README section 6).
/// All data here is the minimised set from README section 9 — name, avatar,
/// progress. No last names, birthdays, photos or free text.
struct Kid: Identifiable {
    let id = UUID()
    var name: String
    var avatarKind: AvatarKind
    var avatarColorIndex: Int

    // Progress / rewards (README section 3).
    var starsByLevel: [Int: Int] = [:]   // level id -> stars earned (0...3)
    var coins: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    // Parent-dashboard figures (README section 6).
    var minutesToday: Int = 0
    var minutesThisWeek: Int = 0

    /// Highest level the child has unlocked. Levels unlock in order.
    var unlockedThrough: Int = 1

    var avatarColor: Color {
        Palette.avatarChoices[avatarColorIndex % Palette.avatarChoices.count]
    }

    /// Total stars across all levels — shown on the map header.
    var totalStars: Int { starsByLevel.values.reduce(0, +) }

    func lockState(for levelID: Int) -> LevelLockState {
        if levelID < unlockedThrough { return .completed }
        if levelID == unlockedThrough { return .current }
        return .locked
    }
}

enum LevelLockState {
    case completed, current, locked
}

// MARK: - Level map (README section 5)

struct MoneyLevel: Identifiable {
    let id: Int           // 1...13, also the unlock order
    let title: String
    let kidSummary: String
    let world: String
    let symbolName: String // SF Symbol placeholder for the Fluent 3D icon
    /// Only Level 2 (Needs & Wants) is a fully playable lesson in this mock-up.
    let isPlayable: Bool
}

enum SampleData {
    /// The 13 levels in 4 worlds, straight from README section 5.
    static let levels: [MoneyLevel] = [
        // World 1 · Money Basics
        MoneyLevel(id: 1,  title: "What Is Money?",        kidSummary: "Money is something people trade for things.",       world: "Money Basics",  symbolName: "dollarsign.circle.fill",     isPlayable: false),
        MoneyLevel(id: 2,  title: "Needs & Wants",          kidSummary: "Needs keep us safe. Wants are fun extras.",         world: "Money Basics",  symbolName: "tshirt.fill",                isPlayable: true),
        MoneyLevel(id: 3,  title: "Earning Money",          kidSummary: "People earn money by doing jobs and helping.",      world: "Money Basics",  symbolName: "hands.sparkles.fill",        isPlayable: false),
        // World 2 · Save & Spend
        MoneyLevel(id: 4,  title: "Saving Up",              kidSummary: "Keep some money now to use it later.",              world: "Save & Spend", symbolName: "banknote.fill",              isPlayable: false),
        MoneyLevel(id: 5,  title: "Smart Spending",         kidSummary: "Stop, think and compare before you buy.",           world: "Save & Spend", symbolName: "cart.fill",                  isPlayable: false),
        MoneyLevel(id: 6,  title: "Making a Budget",        kidSummary: "A money plan: spend some, save some, give some.",   world: "Save & Spend", symbolName: "list.clipboard.fill",        isPlayable: false),
        // World 3 · Money Helpers
        MoneyLevel(id: 7,  title: "How Banks Work",         kidSummary: "A bank keeps money safe until you need it.",        world: "Money Helpers", symbolName: "building.columns.fill",      isPlayable: false),
        MoneyLevel(id: 8,  title: "Interest",               kidSummary: "Saving in a bank can pay you a little extra.",      world: "Money Helpers", symbolName: "sparkles",                   isPlayable: false),
        MoneyLevel(id: 9,  title: "Borrowing & Paying Back", kidSummary: "When you borrow, you promise to give it back.",    world: "Money Helpers", symbolName: "hands.and.sparkles.fill",    isPlayable: false),
        // World 4 · Big Money Ideas
        MoneyLevel(id: 10, title: "Money Safety",           kidSummary: "Keep secrets safe. Ask a grown-up before buying.",  world: "Big Money Ideas", symbolName: "shield.fill",              isPlayable: false),
        MoneyLevel(id: 11, title: "Taxes: Money We Share",  kidSummary: "Money grown-ups share to build things for all.",    world: "Big Money Ideas", symbolName: "building.2.fill",          isPlayable: false),
        MoneyLevel(id: 12, title: "Giving & Sharing",       kidSummary: "Money can help other people and our community.",    world: "Big Money Ideas", symbolName: "gift.fill",                isPlayable: false),
        MoneyLevel(id: 13, title: "Growing Money",          kidSummary: "Investing is like planting a money seed.",          world: "Big Money Ideas", symbolName: "leaf.fill",                isPlayable: false)
    ]

    /// The four worlds, in map order.
    static let worlds: [String] = ["Money Basics", "Save & Spend", "Money Helpers", "Big Money Ideas"]

    static func levels(in world: String) -> [MoneyLevel] {
        levels.filter { $0.world == world }
    }

    static func level(_ id: Int) -> MoneyLevel? {
        levels.first { $0.id == id }
    }

    /// A pre-populated demo kid so the map already shows progress, a streak and
    /// stars without forcing the reviewer through setup first.
    static func demoKid() -> Kid {
        var mia = Kid(name: "Mia", avatarKind: .girl, avatarColorIndex: 0)
        mia.starsByLevel = [1: 3]      // Level 1 finished with 3 stars
        mia.coins = 30
        mia.currentStreak = 3
        mia.bestStreak = 5
        mia.minutesToday = 8
        mia.minutesThisWeek = 42
        mia.unlockedThrough = 2        // Needs & Wants is the current level
        return mia
    }
}
