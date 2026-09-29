//
//  AppState.swift
//  Single source of truth for navigation, and the one door between the screens
//  and the two things underneath them: the on-device store (Persistence/) and
//  the bundled lesson content (Lessons/).
//
//  Screens read `kids` / `settings` and call methods here; they never touch
//  SwiftData or the JSON. Every mutation writes through to the store and then
//  reloads, so what's on screen is always what's saved — which is what makes
//  "close the app, open it again, everything is still there" true.
//

import SwiftUI
import SwiftData

/// Top-level screens. The root view switches on this.
enum Route: Equatable {
    case welcome            // 1. Welcome + "a grown-up sets this up"
    case grownUpCheck       // 2a. Press-and-hold gate
    case createParentCode   // 2b. Create the 6-digit parent code (PIN)
    case addKid             // 2c. Add a kid profile
    case whosLearning       // "Who's learning?" avatar picker
    case lessonMap          // 3. The 13-level path for the selected kid
    case levelLessons       // 3b. One level's lessons + its friendly check
    case lesson             // 4. A lesson, played by the engine
    case parentGate         // 5a. Enter parent code to unlock the dashboard
    case parentDashboard    // 5b. Code-locked parent dashboard
}

extension Route {
    /// Map a UITEST_ROUTE env string to a route (screenshots / UI tests only).
    init?(uiTestName: String) {
        switch uiTestName {
        case "welcome":          self = .welcome
        case "grownUpCheck":     self = .grownUpCheck
        case "createParentCode": self = .createParentCode
        case "addKid":           self = .addKid
        case "whosLearning":     self = .whosLearning
        case "lessonMap":        self = .lessonMap
        case "levelLessons":     self = .levelLessons
        case "lesson":           self = .lesson
        case "parentGate":       self = .parentGate
        case "parentDashboard":  self = .parentDashboard
        default:                 return nil
        }
    }
}

@MainActor
final class AppState: ObservableObject {

    // MARK: Navigation
    @Published var route: Route = .welcome
    @Published var selectedKidID: Kid.ID?
    /// The level whose lesson list is open, if any.
    @Published private(set) var activeLevelID: Int?
    /// The lesson the player is showing, if any.
    @Published private(set) var activeLessonID: String?

    // MARK: Data (loaded from the on-device store)
    @Published private(set) var kids: [Kid] = []
    @Published private(set) var settings = ParentSettings()

    /// The bundled worlds, levels and lessons.
    let library: CurriculumLibrary
    private let store: ProgressStore

    // MARK: Parent-gate lockout (README section 6: wrong codes -> short lockout)
    @Published var failedCodeAttempts = 0
    @Published var lockoutUntil: Date?
    let maxAttemptsBeforeLockout = 4
    let lockoutSeconds: TimeInterval = 30

    // MARK: - Setup

    init(container: ModelContainer,
         library: CurriculumLibrary = CurriculumLibrary.loadOrEmpty(),
         environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.library = library
        self.store = ProgressStore(context: container.mainContext)

        applyUITestSeeds(environment)
        reload()

        // A saved family means we can go straight to "Who's learning?"; an empty
        // store is a real first launch and starts at Welcome, which leads into
        // the grown-up setup flow.
        if !kids.isEmpty { route = .whosLearning }
        selectedKidID = kids.first?.id

        applyUITestRoute(environment)
    }

    /// Re-read everything from the store. Cheap: a handful of rows.
    func reload() {
        kids = store.kids(using: library)
        settings = store.settings()
        LessonAudio.isEnabled = settings.soundOn
        if let selectedKidID, !kids.contains(where: { $0.id == selectedKidID }) {
            self.selectedKidID = kids.first?.id
        }
    }

    var selectedKid: Kid? {
        kids.first { $0.id == selectedKidID }
    }

    // MARK: - Kid mutations

    func addKid(name: String, kind: AvatarKind, colorIndex: Int) {
        let id = store.addKid(name: name, kind: kind, colorIndex: colorIndex)
        reload()
        selectedKidID = id
    }

    // MARK: - Lessons

    /// The step this child should play next in a level: the first lesson they
    /// haven't finished, then the level check, else the first lesson again.
    func nextLesson(inLevel levelID: Int) -> Lesson? {
        library.nextLesson(inLevel: levelID, starsByLesson: selectedKid?.starsByLesson ?? [:])
    }

    var activeLevel: LevelSpec? {
        activeLevelID.flatMap { library.level($0) }
    }

    /// Tapping a level on the map: show its lesson list. A level holds about
    /// five lessons plus a check, so it opens a list rather than one lesson.
    /// Does nothing for a locked level or one whose lessons aren't written yet.
    func openLevel(_ levelID: Int) {
        guard let kid = selectedKid, kid.lockState(for: levelID) != .locked,
              !library.lessonsAndCheck(inLevel: levelID).isEmpty else { return }
        activeLevelID = levelID
        route = .levelLessons
    }

    /// Play one lesson (or a level check) by id.
    func startLesson(id: String) {
        guard let kid = selectedKid, let lesson = library.lesson(id),
              kid.lockState(for: lesson.levelID) != .locked,
              library.isPlayable(lesson, starsByLesson: kid.starsByLesson) else { return }
        activeLevelID = lesson.levelID
        activeLessonID = lesson.id
        route = .lesson
    }

    var activeLesson: Lesson? {
        activeLessonID.flatMap { library.lesson($0) }
    }

    /// Save the result of a finished lesson: stars for that lesson, play coins,
    /// the streak day and the minutes it took. The map reads the saved figures.
    func completeLesson(lessonID: String, stars: Int, coins: Int, minutes: Int) {
        guard let kidID = selectedKidID, let lesson = library.lesson(lessonID) else { return }
        store.recordCompletion(kidID: kidID,
                               lessonID: lessonID,
                               levelID: lesson.levelID,
                               stars: stars,
                               coins: coins,
                               minutes: minutes)
        reload()
    }

    /// Leaving a lesson goes back to its level's list, which is where the
    /// child came from and where the next lesson is waiting.
    func leaveLesson() {
        let levelID = activeLesson?.levelID ?? activeLevelID
        activeLessonID = nil
        if let levelID, !library.lessonsAndCheck(inLevel: levelID).isEmpty {
            activeLevelID = levelID
            route = .levelLessons
        } else {
            route = .lessonMap
        }
    }

    // MARK: - Grown-up settings

    func setDailyLimit(_ minutes: Int) {
        store.setDailyLimit(minutes)
        reload()
    }

    func setSoundOn(_ on: Bool) {
        store.setSoundOn(on)
        reload()
    }

    // MARK: - Parent code

    var hasParentCode: Bool { settings.parentCodeDigits != nil }
    /// How long the stored code is, so the keypad knows when to submit.
    var parentCodeLength: Int? { settings.parentCodeDigits }

    func setParentCode(_ code: String) {
        store.setParentCode(code)
        reload()
    }

    func clearParentCode() {
        store.clearParentCode()
        reload()
    }

    var isLockedOut: Bool {
        guard let until = lockoutUntil else { return false }
        return Date() < until
    }

    var lockoutRemaining: Int {
        guard let until = lockoutUntil else { return 0 }
        return max(0, Int(until.timeIntervalSinceNow.rounded(.up)))
    }

    /// Returns true if the code is correct. Wrong codes accumulate toward a
    /// short lockout (README section 6). Only the hash is ever compared.
    func submitParentCode(_ entered: String) -> Bool {
        guard !isLockedOut else { return false }
        if store.parentCodeMatches(entered) {
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

    // MARK: - Screenshot / UI-test hooks
    //
    // All of these are absent in normal use. Seeding hooks run against a
    // throwaway store by default (see PersistenceController.makeContainer), so a
    // screenshot run never writes into a real child's progress.

    private func applyUITestSeeds(_ environment: [String: String]) {
        if let raw = environment["UITEST_KIDS"] {
            store.seedKids(named: raw.split(separator: ",").map(String.init))
        } else if environment["UITEST_SEED"] == "demo" {
            store.seedDemoKid(library: library)
        }
    }

    private func applyUITestRoute(_ environment: [String: String]) {
        if let raw = environment["UITEST_ROUTE"], let route = Route(uiTestName: raw) {
            self.route = route
        }
        // Open a level's lesson list, e.g. UITEST_LEVEL=2.
        if let raw = environment["UITEST_LEVEL"], let levelID = Int(raw),
           library.level(levelID) != nil {
            activeLevelID = levelID
            if route == .lessonMap { route = .levelLessons }
        }
        // Jump straight into a named lesson, e.g. UITEST_LESSON=what-is-money-1
        // (a level check id such as level-2-check works too).
        if let lessonID = environment["UITEST_LESSON"], let lesson = library.lesson(lessonID) {
            activeLessonID = lessonID
            activeLevelID = lesson.levelID
            route = .lesson
        } else if route == .lesson {
            activeLessonID = library.lesson("needs-and-wants-1") != nil
                ? "needs-and-wants-1"
                : library.levels.compactMap { library.lessons(inLevel: $0.id).first?.id }.first
        }
    }

    /// Which screen of the active lesson to open on, and in what answer state —
    /// `UITEST_LESSON_SCREEN` (a screen id or 1-based number) and
    /// `UITEST_LESSON_FEEDBACK` (`right`, `wrong` or `complete`).
    var uiTestLessonScreen: String? { ProcessInfo.processInfo.environment["UITEST_LESSON_SCREEN"] }
    var uiTestLessonFeedback: String? { ProcessInfo.processInfo.environment["UITEST_LESSON_FEEDBACK"] }
}

#if DEBUG
extension AppState {
    /// A throwaway app for `#Preview` blocks and the map/lesson previews: an
    /// in-memory store seeded with the demo family, so a preview never touches a
    /// real child's saved progress.
    static func preview() -> AppState {
        let environment = ["UITEST_STORE": "memory", "UITEST_SEED": "demo"]
        return AppState(container: PersistenceController.makeContainer(environment: environment),
                        environment: environment)
    }
}
#endif
