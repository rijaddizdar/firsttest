//
//  ProgressStore.swift
//  The only place that reads and writes the SwiftData store.
//
//  Everything above it (AppState, the screens) works with the plain `Kid` value
//  type; this file maps that to and from the records and does the small amount
//  of arithmetic that has to agree with the content: which lessons are finished,
//  how many stars a level shows, how far the map is unlocked, streak days and
//  minutes per day.
//
//  On-device only, no network. See Records.swift for what is stored and why.
//

import Foundation
import SwiftData
import OSLog
import CryptoKit

// MARK: - Container

enum PersistenceController {

    private static let log = Logger(subsystem: "app.persistence", category: "store")

    /// Where the on-device store lives. Named explicitly so a screenshot run can
    /// wipe it (`UITEST_STORE=reset`).
    static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "Progress.store")
    }

    /// Build the container. Screenshot and UI-test runs can ask for a throwaway
    /// store so they never touch (or inherit) a real child's progress:
    ///
    ///   UITEST_STORE=memory   in-memory store, gone when the app quits
    ///   UITEST_STORE=reset    on-disk store, deleted first
    ///   UITEST_STORE=disk     the real on-disk store (the default)
    ///
    /// A run that seeds kids (`UITEST_KIDS`, `UITEST_SEED`) defaults to memory,
    /// so seeded families are never written into the real store.
    static func makeContainer(environment: [String: String] = ProcessInfo.processInfo.environment) -> ModelContainer {
        let schema = Schema(PersistedSchema.models)
        let requested = environment["UITEST_STORE"]?.lowercased()
        let seeds = environment["UITEST_KIDS"] != nil || environment["UITEST_SEED"] != nil
        let mode = requested ?? (seeds ? "memory" : "disk")

        if mode == "memory" {
            return makeInMemory(schema: schema)
        }
        if mode == "reset" {
            for url in [storeURL,
                        storeURL.appendingPathExtension("shm"),
                        storeURL.appendingPathExtension("wal")] {
                try? FileManager.default.removeItem(at: url)
            }
        }
        do {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A store we can't open must not stop a child from using the app.
            log.error("on-disk store unavailable, falling back to memory: \(error.localizedDescription, privacy: .public)")
            return makeInMemory(schema: schema)
        }
    }

    private static func makeInMemory(schema: Schema) -> ModelContainer {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create even an in-memory store: \(error)")
        }
    }
}

// MARK: - Store

/// Reads and writes kids, progress and the grown-up settings.
@MainActor
final class ProgressStore {

    private let context: ModelContext
    private let calendar = Calendar.current
    private static let log = Logger(subsystem: "app.persistence", category: "store")

    /// README section 9: time-per-day is kept on a rolling window, then deleted.
    private let usageRetentionDays = 90

    init(context: ModelContext) {
        self.context = context
        pruneOldUsage()
    }

    // MARK: Kids

    /// Every child, oldest profile first, projected into the value type the
    /// screens use. `library` supplies the level/lesson structure the progress
    /// figures are derived from.
    func kids(using library: CurriculumLibrary) -> [Kid] {
        records().map { kid(from: $0, using: library) }
    }

    func records() -> [KidRecord] {
        let descriptor = FetchDescriptor<KidRecord>(sortBy: [SortDescriptor(\.createdAt)])
        do { return try context.fetch(descriptor) } catch {
            Self.log.error("fetching kids failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func record(_ id: UUID) -> KidRecord? {
        records().first { $0.id == id }
    }

    @discardableResult
    func addKid(name: String, kind: AvatarKind, colorIndex: Int) -> UUID {
        let record = KidRecord(name: name.isEmpty ? "Friend" : name,
                               avatarKindRaw: kind.rawValue,
                               avatarColorIndex: colorIndex)
        context.insert(record)
        save()
        return record.id
    }

    func deleteKid(_ id: UUID) {
        guard let record = record(id) else { return }
        context.delete(record)
        save()
    }

    // MARK: Finishing a lesson

    /// Write the result of a finished lesson: best stars for that lesson, play
    /// coins, the streak day, and the minutes it took.
    func recordCompletion(kidID: UUID,
                          lessonID: String,
                          levelID: Int,
                          stars: Int,
                          coins: Int,
                          minutes: Int) {
        guard let kid = record(kidID) else { return }

        if let existing = kid.lessonResults.first(where: { $0.lessonID == lessonID }) {
            // Replaying a lesson can earn more stars, never fewer.
            existing.stars = max(existing.stars, stars)
            existing.completedAt = Date()
            existing.timesPlayed += 1
        } else {
            let result = LessonResultRecord(lessonID: lessonID, levelID: levelID, stars: stars)
            result.kid = kid
            context.insert(result)
        }

        kid.coins += coins
        bumpStreak(for: kid)
        addMinutes(minutes, to: kid)
        save()
    }

    /// Streaks count DAYS with at least one finished lesson. A second lesson the
    /// same day doesn't bump it, and a missed day quietly starts a new one — the
    /// app never scolds (README section 3 and section 7 rule 6).
    private func bumpStreak(for kid: KidRecord) {
        let today = calendar.startOfDay(for: Date())
        if let last = kid.lastFinishedDay {
            let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            switch days {
            case 0:  break                       // already counted today
            case 1:  kid.currentStreak += 1
            default: kid.currentStreak = 1       // back after a gap: a fresh streak
            }
        } else {
            kid.currentStreak = 1
        }
        kid.lastFinishedDay = today
        kid.bestStreak = max(kid.bestStreak, kid.currentStreak)
    }

    private func addMinutes(_ minutes: Int, to kid: KidRecord) {
        let today = calendar.startOfDay(for: Date())
        if let existing = kid.dailyUsage.first(where: { calendar.isDate($0.day, inSameDayAs: today) }) {
            existing.minutes += minutes
        } else {
            let usage = DailyUsageRecord(day: today, minutes: minutes)
            usage.kid = kid
            context.insert(usage)
        }
    }

    /// Drop day records past the retention window (README section 9).
    private func pruneOldUsage() {
        let cutoff = calendar.date(byAdding: .day, value: -usageRetentionDays,
                                   to: calendar.startOfDay(for: Date())) ?? Date.distantPast
        do {
            let stale = try context.fetch(FetchDescriptor<DailyUsageRecord>(
                predicate: #Predicate { $0.day < cutoff }))
            guard !stale.isEmpty else { return }
            stale.forEach(context.delete)
            save()
        } catch {
            Self.log.error("pruning usage failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Settings and the parent code

    func settingsRecord() -> SettingsRecord {
        do {
            if let existing = try context.fetch(FetchDescriptor<SettingsRecord>()).first { return existing }
        } catch {
            Self.log.error("fetching settings failed: \(error.localizedDescription, privacy: .public)")
        }
        let fresh = SettingsRecord()
        context.insert(fresh)
        save()
        return fresh
    }

    func settings() -> ParentSettings {
        let record = settingsRecord()
        return ParentSettings(dailyLimitMinutes: record.dailyLimitMinutes,
                              soundOn: record.soundOn,
                              parentCodeDigits: record.parentCodeHash == nil ? nil : record.parentCodeDigits)
    }

    func setDailyLimit(_ minutes: Int) {
        settingsRecord().dailyLimitMinutes = minutes
        save()
    }

    func setSoundOn(_ on: Bool) {
        settingsRecord().soundOn = on
        save()
    }

    /// Store a new parent code as a salted hash. The digits are never written.
    func setParentCode(_ code: String) {
        let record = settingsRecord()
        let salt = ParentCode.makeSalt()
        record.parentCodeSalt = salt
        record.parentCodeHash = ParentCode.hash(code, salt: salt)
        record.parentCodeDigits = code.count
        save()
    }

    func clearParentCode() {
        let record = settingsRecord()
        record.parentCodeSalt = nil
        record.parentCodeHash = nil
        record.parentCodeDigits = 0
        save()
    }

    func parentCodeMatches(_ entered: String) -> Bool {
        let record = settingsRecord()
        guard let hash = record.parentCodeHash, let salt = record.parentCodeSalt else { return false }
        return ParentCode.hash(entered, salt: salt) == hash
    }

    // MARK: Seeding (screenshots, demos, first run)

    /// The demo family from the old in-memory mock: one kid with the first level
    /// behind her. Only used by `UITEST_SEED=demo`, never on a real first launch.
    func seedDemoKid(library: CurriculumLibrary) {
        guard records().isEmpty else { return }
        let id = addKid(name: "Mia", kind: .girl, colorIndex: 0)
        guard let kid = record(id) else { return }
        kid.coins = 30
        kid.bestStreak = 5
        kid.currentStreak = 3
        kid.lastFinishedDay = calendar.startOfDay(for: Date())
        addMinutes(8, to: kid)
        setParentCode("1234")
        save()
    }

    /// `UITEST_KIDS=Mia,Jayden,…` — replace the store's kids with this family, to
    /// stress "Who's learning?" with row counts and long names.
    func seedKids(named names: [String]) {
        records().forEach(context.delete)
        for (index, name) in names.enumerated() {
            let record = KidRecord(name: name,
                                   avatarKindRaw: index.isMultiple(of: 2) ? AvatarKind.girl.rawValue : AvatarKind.boy.rawValue,
                                   avatarColorIndex: index,
                                   createdAt: Date().addingTimeInterval(Double(index)))
            context.insert(record)
        }
        if settingsRecord().parentCodeHash == nil { setParentCode("1234") }
        save()
    }

    // MARK: Mapping

    private func kid(from record: KidRecord, using library: CurriculumLibrary) -> Kid {
        var starsByLesson: [String: Int] = [:]
        for result in record.lessonResults {
            starsByLesson[result.lessonID] = max(starsByLesson[result.lessonID] ?? 0, result.stars)
        }

        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let minutesToday = record.dailyUsage
            .filter { calendar.isDate($0.day, inSameDayAs: today) }
            .reduce(0) { $0 + $1.minutes }
        let minutesThisWeek = record.dailyUsage
            .filter { $0.day >= weekStart }
            .reduce(0) { $0 + $1.minutes }

        var starsByLevel: [Int: Int] = [:]
        for level in library.levels {
            let stars = library.stars(forLevel: level.id, starsByLesson: starsByLesson)
            if stars > 0 { starsByLevel[level.id] = stars }
        }

        return Kid(id: record.id,
                   name: record.name,
                   avatarKind: AvatarKind(rawValue: record.avatarKindRaw) ?? .girl,
                   avatarColorIndex: record.avatarColorIndex,
                   coins: record.coins,
                   currentStreak: record.currentStreak,
                   bestStreak: record.bestStreak,
                   minutesToday: minutesToday,
                   minutesThisWeek: minutesThisWeek,
                   starsByLesson: starsByLesson,
                   starsByLevel: starsByLevel,
                   levelStates: library.levelStates(starsByLesson: starsByLesson),
                   unlockedThrough: library.unlockedThrough(starsByLesson: starsByLesson))
    }

    // MARK: Saving

    private func save() {
        do { try context.save() } catch {
            Self.log.error("saving failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Parent code hashing

/// The parent code is never stored in plain text (README section 9). On device
/// that means a per-install random salt and SHA-256; the server-side equivalent
/// is a slow KDF, which is a backend task.
enum ParentCode {
    static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices { bytes[index] = UInt8.random(in: .min ... .max) }
        return Data(bytes).base64EncodedString()
    }

    static func hash(_ code: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
