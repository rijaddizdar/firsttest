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
    /// The dashboard says this number out loud, so it isn't private.
    static let usageRetentionDays = 90
    private var usageRetentionDays: Int { Self.usageRetentionDays }

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

    /// Add a profile. `hasFinishedFirstRun` is false for a profile a grown-up
    /// just made, so the child's own first time — name, "Make it yours!", meet
    /// Penny — still runs the first time they tap their own face.
    @discardableResult
    func addKid(name: String, avatar: Avatar, hasFinishedFirstRun: Bool = false) -> UUID {
        let record = KidRecord(name: name.isEmpty ? "Friend" : name,
                               avatarKindRaw: avatar.kind.rawValue,
                               avatarColorIndex: avatar.outfitColorIndex,
                               avatarHairstyleRaw: avatar.hairstyle.rawValue,
                               avatarSkinToneIndex: avatar.skinToneIndex,
                               avatarHairColorIndex: avatar.hairColorIndex,
                               hasFinishedFirstRun: hasFinishedFirstRun)
        context.insert(record)
        save()
        return record.id
    }

    /// Save a change a child (or a grown-up) made to their name or their look.
    /// Passing nil for either leaves it alone.
    func updateKid(_ id: UUID, name: String? = nil, avatar: Avatar? = nil) {
        guard let record = record(id) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { record.name = trimmed }
        }
        if let avatar {
            record.avatarKindRaw = avatar.kind.rawValue
            record.avatarColorIndex = avatar.outfitColorIndex
            record.avatarHairstyleRaw = avatar.hairstyle.rawValue
            record.avatarSkinToneIndex = avatar.skinToneIndex
            record.avatarHairColorIndex = avatar.hairColorIndex
        }
        save()
    }

    /// The child has met Penny; from now on their face opens the map.
    func markFirstRunFinished(_ id: UUID) {
        guard let record = record(id) else { return }
        record.hasFinishedFirstRun = true
        save()
    }

    /// Delete one child and everything attached to them. The lesson results and
    /// day records go with them (`.cascade` on the relationships in
    /// Records.swift), so nothing about that child is left behind.
    func deleteKid(_ id: UUID) {
        guard let record = record(id) else { return }
        context.delete(record)
        save()
    }

    /// Delete everything the app has saved: every child, their progress and
    /// their day records, plus the grown-up settings and the parent code hash.
    /// README section 6 promises this from inside the app, and afterwards the
    /// store is exactly as empty as it is on a fresh install — which is what
    /// sends the app back to first launch.
    func deleteAllData() {
        records().forEach(context.delete)
        do {
            try context.fetch(FetchDescriptor<SettingsRecord>()).forEach(context.delete)
            // Belt and braces: anything orphaned by an earlier crash goes too.
            try context.fetch(FetchDescriptor<LessonResultRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<DailyUsageRecord>()).forEach(context.delete)
        } catch {
            Self.log.error("deleting all data failed: \(error.localizedDescription, privacy: .public)")
        }
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

    /// Penny's scales, awarded the moment a LEVEL is finished rather than a
    /// lesson (README section 3: "Finishing a level adds new shiny scales to
    /// Penny"). Call it straight after `recordCompletion`, which is what makes
    /// the level complete; it returns how many scales were added so the Yay!
    /// screen can say so, and 0 on every other lesson.
    ///
    /// Idempotent in the way that matters: replaying a finished level does not
    /// hand out a second batch, because the level was already complete before
    /// the replay.
    @discardableResult
    func awardScalesIfLevelFinished(kidID: UUID,
                                    levelID: Int,
                                    wasCompleteBefore: Bool,
                                    library: CurriculumLibrary) -> Int {
        guard !wasCompleteBefore, let kid = record(kidID) else { return 0 }
        var starsByLesson: [String: Int] = [:]
        for result in kid.lessonResults {
            starsByLesson[result.lessonID] = max(starsByLesson[result.lessonID] ?? 0, result.stars)
        }
        guard library.isLevelComplete(levelID, starsByLesson: starsByLesson) else { return 0 }
        kid.pennyScales += PennyScales.perLevel
        save()
        return PennyScales.perLevel
    }

    // MARK: Spending play coins

    /// Buy a shop item with play coins. Returns false — and spends nothing — if
    /// the child already owns it or can't afford it, so a screen that is a moment
    /// out of date can never overdraw a balance.
    ///
    /// Play coins are only ever earned by finishing lessons. There is no
    /// in-app purchase and no real-money path anywhere in the app.
    @discardableResult
    func buy(itemID: String, price: Int, kidID: UUID) -> Bool {
        guard price >= 0, let kid = record(kidID) else { return false }
        guard !kid.purchases.contains(where: { $0.itemID == itemID }) else { return false }
        guard kid.coins >= price else { return false }

        kid.coins -= price
        let purchase = ShopPurchaseRecord(itemID: itemID)
        purchase.kid = kid
        context.insert(purchase)
        save()
        return true
    }

    /// Choose the scarf colour Penny wears. A customization choice, which is
    /// what README section 9 allows us to keep (`nil` = Penny's own colour).
    func setPennyScarf(itemID: String?, kidID: UUID) {
        guard let kid = record(kidID) else { return }
        kid.pennyScarfItemID = itemID
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
        let id = addKid(name: "Mia",
                        avatar: Avatar(kind: .girl, hairstyle: .braids,
                                       skinToneIndex: 4, hairColorIndex: 0, outfitColorIndex: 0),
                        hasFinishedFirstRun: true)
        guard let kid = record(id) else { return }
        kid.coins = 30
        kid.bestStreak = 5
        kid.currentStreak = 3
        kid.lastFinishedDay = calendar.startOfDay(for: Date())
        addMinutes(8, to: kid)
        setParentCode("1234")
        save()
    }

    /// `UITEST_SEED=dashboard` — a family with enough history to photograph the
    /// parent dashboard: two kids, finished lessons, and minutes spread over the
    /// last two weeks. Never used on a real launch, and (like every seed) it runs
    /// against a throwaway store by default.
    func seedDashboardFamily(library: CurriculumLibrary) {
        guard records().isEmpty else { return }
        let today = calendar.startOfDay(for: Date())

        func addUsage(_ minutes: [Int], to kid: KidRecord) {
            for (back, minutes) in minutes.enumerated() where minutes > 0 {
                guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
                let usage = DailyUsageRecord(day: day, minutes: minutes)
                usage.kid = kid
                context.insert(usage)
            }
        }

        func finish(_ lessons: [Lesson], stars: Int, for kid: KidRecord) {
            for lesson in lessons {
                let result = LessonResultRecord(lessonID: lesson.id, levelID: lesson.levelID, stars: stars)
                result.kid = kid
                context.insert(result)
            }
        }

        let miaID = addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0),
                            hasFinishedFirstRun: true)
        if let mia = record(miaID) {
            mia.coins = 60
            mia.currentStreak = 4
            mia.bestStreak = 6
            mia.lastFinishedDay = today
            finish(library.lessons(inLevel: 1), stars: 3, for: mia)
            finish(Array(library.lessons(inLevel: 2).prefix(1)), stars: 2, for: mia)
            addUsage([12, 9, 14, 7, 0, 0, 11, 8, 0, 6, 15, 0, 4, 10], to: mia)
        }

        let jaydenID = addKid(name: "Jayden", avatar: .defaultLook(kind: .boy, outfitColorIndex: 3),
                               hasFinishedFirstRun: true)
        if let jayden = record(jaydenID) {
            jayden.coins = 20
            jayden.currentStreak = 1
            jayden.bestStreak = 2
            jayden.lastFinishedDay = today
            finish(Array(library.lessons(inLevel: 1).prefix(1)), stars: 3, for: jayden)
            addUsage([5, 0, 0, 8, 0, 0, 0, 3], to: jayden)
        }

        setParentCode("123456")
        save()
    }

    /// `UITEST_SEED=rewards` — the demo kid part-way through the rewards, so a
    /// screenshot shows all three shop states at once: stickers already bought,
    /// stickers she can afford, and stickers she can't afford yet.
    ///
    /// Built out of the real methods rather than by setting fields, so the
    /// figures agree with each other: the stars, the lessons finished, the
    /// scales and the balance are all consequences of the lessons she played
    /// and the things she bought.
    func seedRewardsKid(library: CurriculumLibrary) {
        guard records().isEmpty else { return }
        let id = addKid(name: "Mia", kind: .girl, colorIndex: 0)
        let lessons = library.lessons(inLevel: 2)
        guard !lessons.isEmpty else { return }

        // Three days of use, a day apart, so the streak on screen is one the
        // streak rules actually produced rather than a number written in.
        recordCompletion(kidID: id, lessonID: lessons[0].id, levelID: lessons[0].levelID,
                         stars: 3, coins: lessons[0].coins, minutes: 4)
        pretendTheLastLessonWasYesterday(id)

        if lessons.count > 1 {
            recordCompletion(kidID: id, lessonID: lessons[1].id, levelID: lessons[1].levelID,
                             stars: 2, coins: lessons[1].coins, minutes: 4)
        }
        awardScalesIfLevelFinished(kidID: id, levelID: lessons[0].levelID,
                                   wasCompleteBefore: false, library: library)
        pretendTheLastLessonWasYesterday(id)

        // A replay earns coins again but never fewer stars, which is what gives
        // her something to spend.
        for lesson in lessons {
            recordCompletion(kidID: id, lessonID: lesson.id, levelID: lesson.levelID,
                             stars: 3, coins: lesson.coins, minutes: 3)
        }

        // Spend some of it, so the shop has owned, affordable and not-yet-
        // affordable items on screen together.
        buy(itemID: "sticker-glowing-star", price: 5, kidID: id)
        buy(itemID: "sticker-rainbow", price: 10, kidID: id)
        if buy(itemID: "scarf-coral", price: 15, kidID: id) {
            setPennyScarf(itemID: "scarf-coral", kidID: id)
        }
        setParentCode("1234")
        save()
    }

    /// Move a seeded child's last finished day back one day, so the next
    /// `recordCompletion` counts as the next day of a streak. Seeds only.
    private func pretendTheLastLessonWasYesterday(_ id: UUID) {
        guard let record = record(id), let last = record.lastFinishedDay else { return }
        record.lastFinishedDay = calendar.date(byAdding: .day, value: -1, to: last)
    }

    /// `UITEST_KIDS=Mia,Jayden,…` — replace the store's kids with this family, to
    /// stress "Who's learning?" with row counts and long names.
    func seedKids(named names: [String]) {
        records().forEach(context.delete)
        for (index, name) in names.enumerated() {
            // Walk through the builder's choices so a seeded family shows a
            // range of looks rather than eight of the same child.
            let kind: AvatarKind = index.isMultiple(of: 2) ? .girl : .boy
            let styles = Hairstyle.choices(for: kind)
            let avatar = Avatar(kind: kind,
                                hairstyle: styles[index % styles.count],
                                skinToneIndex: (index * 2) % Palette.avatarSkinTones.count,
                                hairColorIndex: (index * 3) % Palette.avatarHairColors.count,
                                outfitColorIndex: index)
            let record = KidRecord(name: name,
                                   avatarKindRaw: avatar.kind.rawValue,
                                   avatarColorIndex: avatar.outfitColorIndex,
                                   avatarHairstyleRaw: avatar.hairstyle.rawValue,
                                   avatarSkinToneIndex: avatar.skinToneIndex,
                                   avatarHairColorIndex: avatar.hairColorIndex,
                                   hasFinishedFirstRun: true,
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
        // Every day still inside the retention window, oldest first — the
        // dashboard's "minutes per day" (README section 6).
        let dailyMinutes = record.dailyUsage
            .sorted { $0.day < $1.day }
            .map { DayMinutes(day: calendar.startOfDay(for: $0.day), minutes: $0.minutes) }

        var starsByLevel: [Int: Int] = [:]
        for level in library.levels {
            let stars = library.stars(forLevel: level.id, starsByLesson: starsByLesson)
            if stars > 0 { starsByLevel[level.id] = stars }
        }

        return Kid(id: record.id,
                   name: record.name,
                   avatar: Self.avatar(from: record),
                   hasFinishedFirstRun: record.hasFinishedFirstRun ?? true,
                   coins: record.coins,
                   currentStreak: record.currentStreak,
                   bestStreak: record.bestStreak,
                   pennyScales: record.pennyScales,
                   ownedItemIDs: Set(record.purchases.map(\.itemID)),
                   pennyScarfItemID: record.pennyScarfItemID,
                   minutesToday: minutesToday,
                   minutesThisWeek: minutesThisWeek,
                   dailyMinutes: dailyMinutes,
                   starsByLesson: starsByLesson,
                   starsByLevel: starsByLevel,
                   levelStates: library.levelStates(starsByLesson: starsByLesson),
                   unlockedThrough: library.unlockedThrough(starsByLesson: starsByLesson))
    }

    /// Read a saved look back. A profile written before the avatar builder
    /// existed has no hairstyle on it; it keeps the boy/girl look and outfit
    /// colour it chose and takes the builder's default for the rest, so it
    /// still loads and still looks like somebody.
    static func avatar(from record: KidRecord) -> Avatar {
        let kind = AvatarKind(rawValue: record.avatarKindRaw) ?? .girl
        guard let raw = record.avatarHairstyleRaw, let hairstyle = Hairstyle(rawValue: raw) else {
            return Avatar.defaultLook(kind: kind, outfitColorIndex: record.avatarColorIndex)
        }
        return Avatar(kind: kind,
                      hairstyle: hairstyle,
                      skinToneIndex: record.avatarSkinToneIndex ?? 2,
                      hairColorIndex: record.avatarHairColorIndex ?? 0,
                      outfitColorIndex: record.avatarColorIndex)
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
