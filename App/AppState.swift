//
//  AppState.swift
//  Single source of truth for the mock-up's navigation and in-memory data.
//
//  Uses an enum-driven top-level flow (see `Route`) plus a small amount of
//  parent-gate state. In the real app the persistent parts move to SwiftData and
//  the parent code becomes a salted hash on the backend (README section 9).
//

import SwiftUI
import Combine

/// Top-level screens. The root view switches on this.
enum Route: Equatable {
    case welcome            // 1. Welcome + "a grown-up sets this up"
    case grownUpCheck       // 2a. Press-and-hold gate
    case createParentCode   // 2b. Create the 6-digit parent code (PIN)
    case addKid             // 2c. Add a kid profile
    case whosLearning       // "Who's learning?" avatar picker
    case lessonMap          // 3. The 13-level path for the selected kid
    case lesson             // 4. The playable Needs & Wants lesson
    case parentGate         // 5a. Enter parent code to unlock the dashboard
    case parentDashboard    // 5b. Code-locked parent dashboard
}

/// Per-kid parental control (README section 6).
struct ParentSettings {
    var dailyLimitMinutes: Int = 20
}

final class AppState: ObservableObject {

    // MARK: Navigation
    @Published var route: Route = .welcome
    @Published var selectedKidID: Kid.ID?

    // MARK: Data (in memory only)
    @Published var kids: [Kid]
    @Published var parentCode: String?              // 6-digit PIN; nil until set
    @Published var settings = ParentSettings()

    // MARK: Parent-gate lockout (README section 6: wrong codes -> short lockout)
    @Published var failedCodeAttempts = 0
    @Published var lockoutUntil: Date?
    let maxAttemptsBeforeLockout = 4
    let lockoutSeconds: TimeInterval = 30

    init() {
        // Seed a demo kid so the reviewer can jump straight to the map/lesson.
        // Fresh-setup flow (grown-up check -> code -> add kid) is still fully
        // reachable from the Welcome screen.
        let mia = SampleData.demoKid()
        self.kids = [mia]
        self.selectedKidID = mia.id
        self.parentCode = "1234" // demo PIN so the dashboard is reachable
    }

    var selectedKid: Kid? {
        kids.first { $0.id == selectedKidID }
    }

    // MARK: - Kid mutations

    func addKid(name: String, kind: AvatarKind, colorIndex: Int) {
        var kid = Kid(name: name.isEmpty ? "Friend" : name,
                      avatarKind: kind,
                      avatarColorIndex: colorIndex)
        kid.unlockedThrough = 1
        kids.append(kid)
        selectedKidID = kid.id
    }

    /// Apply the results of finishing a lesson to the selected kid.
    func completeLesson(levelID: Int, stars: Int, coins: Int) {
        guard let idx = kids.firstIndex(where: { $0.id == selectedKidID }) else { return }
        // Keep the best star result if the lesson is replayed.
        let existing = kids[idx].starsByLevel[levelID] ?? 0
        kids[idx].starsByLevel[levelID] = max(existing, stars)
        kids[idx].coins += coins
        // Unlock the next level.
        kids[idx].unlockedThrough = max(kids[idx].unlockedThrough, levelID + 1)
        // Bump the streak once per finished lesson (mock: no real day tracking).
        kids[idx].currentStreak += 1
        kids[idx].bestStreak = max(kids[idx].bestStreak, kids[idx].currentStreak)
        kids[idx].minutesToday += 3
        kids[idx].minutesThisWeek += 3
    }

    // MARK: - Parent code

    var hasParentCode: Bool { parentCode != nil }

    var isLockedOut: Bool {
        guard let until = lockoutUntil else { return false }
        return Date() < until
    }

    var lockoutRemaining: Int {
        guard let until = lockoutUntil else { return 0 }
        return max(0, Int(until.timeIntervalSinceNow.rounded(.up)))
    }

    /// Returns true if the code is correct. Wrong codes accumulate toward a
    /// short lockout (README section 6).
    func submitParentCode(_ entered: String) -> Bool {
        guard !isLockedOut else { return false }
        if entered == parentCode {
            failedCodeAttempts = 0
            lockoutUntil = nil
            return true
        }
        failedCodeAttempts += 1
        if failedCodeAttempts >= maxAttemptsBeforeLockout {
            lockoutUntil = Date().addingTimeInterval(lockoutSeconds)
            failedCodeAttempts = 0
        }
        return false
    }
}
