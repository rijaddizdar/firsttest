//
//  CurriculumLibrary.swift
//  Loads the bundled content (Content/curriculum.json + Content/lessons/*.json),
//  validates it, and answers the questions the app asks of it: what's on the
//  map, which lesson comes next, which levels are unlocked.
//
//  Loading happens once at launch. Structural problems raise a `ContentError`
//  whose message names the file and the fix; the app then falls back to an empty
//  curriculum (a map of "Coming soon" rows) rather than crashing in a child's
//  hands, and trips an assertion in DEBUG so whoever edited the JSON sees it.
//

import Foundation
import OSLog

struct CurriculumLibrary {

    let worlds: [WorldSpec]
    /// Lessons by id, in the order the curriculum lists them.
    private let lessonsByID: [String: Lesson]
    /// Problems found while loading. Empty on a healthy bundle.
    let issues: [String]

    static let empty = CurriculumLibrary(worlds: [], lessonsByID: [:], issues: [])

    private static let log = Logger(subsystem: "app.lessons", category: "content")

    // MARK: - Lookups

    var levels: [LevelSpec] { worlds.flatMap(\.levels) }

    func world(containing levelID: Int) -> WorldSpec? {
        worlds.first { $0.levels.contains { $0.id == levelID } }
    }

    func level(_ id: Int) -> LevelSpec? { levels.first { $0.id == id } }

    func lesson(_ id: String) -> Lesson? { lessonsByID[id] }

    /// The lessons of a level, in play order, skipping ids that failed to load.
    func lessons(inLevel levelID: Int) -> [Lesson] {
        guard let level = level(levelID) else { return [] }
        return level.lessons.compactMap { lessonsByID[$0] }
    }

    /// The lesson a child should play when they tap a level: the first one they
    /// haven't finished, or the first one again once the level is done.
    /// (A lesson picker belongs to the lessons PR; until then the level plays
    /// forward on its own.)
    func nextLesson(inLevel levelID: Int, starsByLesson: [String: Int]) -> Lesson? {
        let lessons = lessons(inLevel: levelID)
        return lessons.first { starsByLesson[$0.id] == nil } ?? lessons.first
    }

    // MARK: - Progress maths

    /// Has every lesson of this level been finished at least once?
    func isLevelComplete(_ levelID: Int, starsByLesson: [String: Int]) -> Bool {
        let lessons = lessons(inLevel: levelID)
        guard !lessons.isEmpty else { return false }   // nothing written yet
        return lessons.allSatisfy { starsByLesson[$0.id] != nil }
    }

    /// The level's star rating on the map: the average of its lessons' best
    /// results, rounded down, once every lesson in it is finished.
    func stars(forLevel levelID: Int, starsByLesson: [String: Int]) -> Int {
        let lessons = lessons(inLevel: levelID)
        let earned = lessons.compactMap { starsByLesson[$0.id] }
        guard !lessons.isEmpty, earned.count == lessons.count else { return 0 }
        let average = Double(earned.reduce(0, +)) / Double(earned.count)
        return min(3, max(1, Int(average.rounded(.down))))
    }

    /// The level the child is on — the one the map rings and opens.
    ///
    /// Levels unlock in order, but a level whose lessons aren't written yet must
    /// not dead-end the map, so it is stepped over: the frontier is the first
    /// level AFTER the last finished one that has lessons. When everything
    /// written is finished, the frontier is simply the next level in line, shown
    /// as "Coming soon" — so the path still reads as a path instead of springing
    /// open all the way to level 13.
    func unlockedThrough(starsByLesson: [String: Int]) -> Int {
        let ordered = levels.sorted { $0.id < $1.id }
        let lastCompleted = ordered
            .filter { isLevelComplete($0.id, starsByLesson: starsByLesson) }
            .map(\.id).max() ?? 0
        let ahead = ordered.filter { $0.id > lastCompleted }
        if let next = ahead.first(where: \.hasLessons) { return next.id }
        return ahead.first?.id ?? (ordered.last?.id ?? 0) + 1
    }

    /// Map state for every level, ready for `LessonMapView`.
    func levelStates(starsByLesson: [String: Int]) -> [Int: LevelLockState] {
        let frontier = unlockedThrough(starsByLesson: starsByLesson)
        var states: [Int: LevelLockState] = [:]
        for level in levels {
            if level.id > frontier {
                states[level.id] = .locked
            } else if level.id == frontier {
                states[level.id] = .current
            } else if isLevelComplete(level.id, starsByLesson: starsByLesson) {
                states[level.id] = .completed
            } else {
                // Behind the frontier but not finished: a level whose lessons
                // aren't written yet. Unlocked, and honest about being empty.
                states[level.id] = .open
            }
        }
        return states
    }

    // MARK: - Loading

    /// Load and validate the bundled content. Throws on the first unusable file.
    static func load(from bundle: Bundle = .main) throws -> CurriculumLibrary {
        guard let curriculumURL = resourceURL("curriculum", subdirectory: "Content", in: bundle) else {
            throw ContentError.missingCurriculum
        }
        let curriculum: Curriculum = try decode(Curriculum.self, at: curriculumURL, named: "curriculum.json")
        guard curriculum.schemaVersion == Curriculum.supportedSchemaVersion else {
            throw ContentError.unsupportedSchemaVersion(found: curriculum.schemaVersion,
                                                        supported: Curriculum.supportedSchemaVersion)
        }

        var issues: [String] = []
        issues += curriculumProblems(curriculum)

        let knownLevelIDs = Set(curriculum.levels.map(\.id))
        var lessons: [String: Lesson] = [:]
        for lessonID in curriculum.levels.flatMap(\.lessons) {
            let file = "\(lessonID).json"
            guard let url = resourceURL(lessonID, subdirectory: "Content/lessons", in: bundle) else {
                throw ContentError.missingLessonFile(id: lessonID, expectedFile: "Content/lessons/\(file)")
            }
            let lesson: Lesson = try decode(Lesson.self, at: url, named: file)
            let problems = lesson.validationProblems(expectedID: lessonID, knownLevelIDs: knownLevelIDs)
            guard problems.isEmpty else { throw ContentError.invalid(file: file, problems: problems) }
            if let level = curriculum.levels.first(where: { $0.id == lesson.levelID }),
               !level.lessons.contains(lessonID) {
                issues.append("\(file) says levelID \(lesson.levelID), but level \(level.id) does not list it.")
            }
            lessons[lessonID] = lesson
        }

        // A lesson file nobody references is invisible in the app; say so rather
        // than let a writer wonder where their lesson went.
        let referenced = Set(curriculum.levels.flatMap(\.lessons))
        for url in bundle.urls(forResourcesWithExtension: "json", subdirectory: "Content/lessons") ?? [] {
            let id = url.deletingPathExtension().lastPathComponent
            if !referenced.contains(id) {
                issues.append("Content/lessons/\(id).json is in the bundle but no level in curriculum.json lists it, so it never plays.")
            }
        }

        for issue in issues { log.warning("content: \(issue, privacy: .public)") }
        return CurriculumLibrary(worlds: curriculum.worlds, lessonsByID: lessons, issues: issues)
    }

    /// Load, or fall back to an empty curriculum so a bad file never stops a
    /// child from opening the app. DEBUG builds trip an assertion instead.
    static func loadOrEmpty(from bundle: Bundle = .main) -> CurriculumLibrary {
        do {
            return try load(from: bundle)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            log.error("content failed to load: \(message, privacy: .public)")
            assertionFailure("Lesson content failed to load.\n\(message)")
            return CurriculumLibrary(worlds: [], lessonsByID: [:], issues: [message])
        }
    }

    // MARK: - Loading helpers

    private static func curriculumProblems(_ curriculum: Curriculum) -> [String] {
        var problems: [String] = []
        if curriculum.worlds.isEmpty { problems.append("curriculum.json has no worlds.") }
        let levelIDs = curriculum.levels.map(\.id)
        let duplicateLevels = Set(levelIDs.filter { id in levelIDs.filter { $0 == id }.count > 1 })
        if !duplicateLevels.isEmpty {
            problems.append("curriculum.json repeats level id(s) \(duplicateLevels.sorted().map(String.init).joined(separator: ", ")).")
        }
        let lessonIDs = curriculum.levels.flatMap(\.lessons)
        let duplicateLessons = Set(lessonIDs.filter { id in lessonIDs.filter { $0 == id }.count > 1 })
        if !duplicateLessons.isEmpty {
            problems.append("curriculum.json lists lesson(s) \(duplicateLessons.sorted().joined(separator: ", ")) more than once.")
        }
        for level in curriculum.levels where !ContentArt.exists(level.icon) {
            problems.append("level \(level.id) asks for the picture \"\(level.icon)\", which is not in Assets.xcassets/Icons.")
        }
        return problems
    }

    /// Find a bundled JSON file. Prefers the folder-referenced `Content` tree and
    /// falls back to a flat copy, so the app keeps working if the resource ever
    /// gets added as a plain file instead.
    private static func resourceURL(_ name: String, subdirectory: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json")
    }

    private static func decode<T: Decodable>(_ type: T.Type, at url: URL, named file: String) throws -> T {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentError.decoding(file: file, detail: error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ContentError.decoding(file: file, detail: Self.describe(error))
        } catch {
            throw ContentError.decoding(file: file, detail: error.localizedDescription)
        }
    }

    /// Turn a `DecodingError` into a sentence that points at the JSON.
    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let parts = context.codingPath.map { key in
                key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)"
            }
            let joined = parts.joined()
            return joined.isEmpty ? "the top level" : String(joined.dropFirst(joined.hasPrefix(".") ? 1 : 0))
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "\"\(key.stringValue)\" is missing at \(path(context))."
        case .typeMismatch(let type, let context):
            return "\(path(context)) should be a \(type)."
        case .valueNotFound(let type, let context):
            return "\(path(context)) has no value; a \(type) was expected."
        case .dataCorrupted(let context):
            return "\(context.debugDescription) (at \(path(context)))"
        @unknown default:
            return error.localizedDescription
        }
    }
}
