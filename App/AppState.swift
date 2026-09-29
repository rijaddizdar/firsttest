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
    case kidFirstRun        // 2d. The child's own first time: name, look, Penny
    case editAvatar         // "Make it yours!" again, from the map header
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
        case "kidFirstRun":      self = .kidFirstRun
        case "editAvatar":       self = .editAvatar
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

    /// Add a profile from the grown-up flow. The child still gets their own
    /// first time — name, "Make it yours!", meet Penny — when they first tap
    /// their face (README section 6).
    @discardableResult
    func addKid(name: String, avatar: Avatar) -> Kid.ID {
        let id = store.addKid(name: name, avatar: avatar)
        reload()
        selectedKidID = id
        return id
    }

    /// Save a change to a child's name or look. Used by the first-time flow and
    /// by "Make it yours!" reached from the map.
    func updateKid(_ id: Kid.ID, name: String? = nil, avatar: Avatar? = nil) {
        store.updateKid(id, name: name, avatar: avatar)
        reload()
    }

    /// The child has met Penny. Their face opens the map from now on.
    func finishKidFirstRun(_ id: Kid.ID) {
        store.markFirstRunFinished(id)
        reload()
    }

    /// What tapping a face on "Who's learning?" does: the map for a child who
    /// has been here before, their own first time for a brand-new profile.
    func openKid(_ id: Kid.ID) {
        selectedKidID = id
        let started = kids.first { $0.id == id }?.hasFinishedFirstRun ?? true
        route = started ? .lessonMap : .kidFirstRun
    }

    /// Delete one child and everything saved about them (README section 6,
    /// "Data"). Their lesson results and day records go with them.
    func deleteKid(_ id: Kid.ID) {
        store.deleteKid(id)
        // `reload` drops a selection that no longer exists and falls back to a
        // child who still does, so deleting the selected one is already handled.
        reload()
    }

    /// Delete everything: every child, all progress, and the grown-up settings
    /// including the parent code. The store is then as empty as a fresh install,
    /// so the app goes back to first launch — that is what "delete the whole
    /// account" has to mean while there is no backend.
    func deleteAllData() {
        store.deleteAllData()
        selectedKidID = nil
        activeLessonID = nil
        reload()
        failedCodeAttempts = 0
        lockoutUntil = nil
        route = .welcome
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
              !hasReachedDailyLimit(kid),
              !library.lessonsAndCheck(inLevel: levelID).isEmpty else { return }
        activeLevelID = levelID
        route = .levelLessons
    }

    /// Play one lesson (or a level check) by id.
    func startLesson(id: String) {
        guard let kid = selectedKid, let lesson = library.lesson(id),
              kid.lockState(for: lesson.levelID) != .locked,
              // The day's time is checked when a lesson STARTS, never during
              // one, so a lesson already open always finishes (README §6).
              !hasReachedDailyLimit(kid),
              library.isPlayable(lesson, starsByLesson: kid.starsByLesson) else { return }
        activeLevelID = lesson.levelID
        activeLessonID = lesson.id
        route = .lesson
    }

    // MARK: - The daily time limit (README section 6)
    //
    // The limit is checked when a lesson STARTS, never during one: "the current
    // lesson finishes first, so progress is never lost mid-lesson". When it is
    // reached the map simply stops opening lessons and Penny says so kindly —
    // no countdown, no "hurry", no guilt (README section 7, rule 6).

    /// True once this child has spent at least the day's allowance today.
    func hasReachedDailyLimit(_ kid: Kid) -> Bool {
        settings.hasDailyLimit && kid.minutesToday >= settings.dailyLimitMinutes
    }

    /// Minutes of today's allowance left, or nil when there is no limit.
    func minutesLeftToday(_ kid: Kid) -> Int? {
        guard settings.hasDailyLimit else { return nil }
        return max(0, settings.dailyLimitMinutes - kid.minutesToday)
    }

    /// Penny's wrap-up when the time is up, in her own words (README section 6).
    func dailyLimitMessage(for kid: Kid) -> String {
        "That's all for today, \(kid.name)! Let's learn more tomorrow."
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
        } else if environment["UITEST_SEED"] == "dashboard" {
            store.seedDashboardFamily(library: library)
        }
        // A screenshot run can pin the daily limit, e.g. UITEST_DAILY_LIMIT=0
        // for "no limit" or a small number to photograph the wrap-up on the map.
        if let raw = environment["UITEST_DAILY_LIMIT"], let minutes = Int(raw) {
            store.setDailyLimit(minutes)
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

    /// Which grown-up panel the dashboard should open on: `changeCode`,
    /// `deleteKid` or `deleteAll` (screenshots only).
    var uiTestDashboardPanel: String? { ProcessInfo.processInfo.environment["UITEST_DASHBOARD"] }

    /// Which screen of the active lesson to open on, and in what answer state —
    /// `UITEST_LESSON_SCREEN` (a screen id or 1-based number) and
    /// `UITEST_LESSON_FEEDBACK` (`right`, `wrong` or `complete`).
    /// Which step of the child's first time to open on — `name`, `look` or
    /// `penny`. Only read when the route is already `kidFirstRun`.
    var uiTestFirstRunStep: String? { ProcessInfo.processInfo.environment["UITEST_FIRSTRUN_STEP"] }

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

    /// The same, seeded with a family that has enough history for the parent
    /// dashboard to have something to draw.
    static func previewDashboard() -> AppState {
        let environment = ["UITEST_STORE": "memory", "UITEST_SEED": "dashboard"]
        return AppState(container: PersistenceController.makeContainer(environment: environment),
                        environment: environment)
    }
}
#endif
