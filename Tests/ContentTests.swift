//
//  ContentTests.swift
//  The bundled content must load, and a broken lesson must fail with a message
//  a writer can act on. These are the two things that decide whether "writers
//  add lessons without code changes" actually holds.
//

import XCTest
@testable import MoneyPals

final class ContentTests: XCTestCase {

    /// Everything in App/Content loads, validates and is reachable.
    func testBundledContentLoadsCleanly() throws {
        let library = try CurriculumLibrary.load(from: .main)
        XCTAssertTrue(library.issues.isEmpty, "content issues: \(library.issues)")
        XCTAssertFalse(library.worlds.isEmpty)
        XCTAssertNotNil(library.lesson("needs-and-wants-1"))
        XCTAssertNotNil(library.lesson("sample-screen-types"))
    }

    /// The ported lesson still says what it said when it was hard-coded.
    func testPortedLessonKeepsItsContent() throws {
        let library = try CurriculumLibrary.load(from: .main)
        let lesson = try XCTUnwrap(library.lesson("needs-and-wants-1"))
        XCTAssertEqual(lesson.levelID, 2)
        XCTAssertFalse(lesson.isSample)
        XCTAssertEqual(lesson.coins, 10)
        XCTAssertEqual(lesson.questionScreens.count, 2)

        guard case .hello(let hello) = lesson.screens.first else {
            return XCTFail("a lesson opens on a hello screen")
        }
        XCTAssertEqual(hello.penny, "Hi, {name}! Today we'll learn about needs and wants!")

        guard case .tapToChoose(let question) = lesson.screens[2] else {
            return XCTFail("screen 3 is the coat question")
        }
        XCTAssertEqual(question.prompt, "It's snowing outside. Is a warm coat a need or a want?")
        XCTAssertEqual(question.choices.first(where: \.correct)?.label, "Need")
    }

    /// The sample lesson covers the screen types the port doesn't.
    func testSampleLessonCoversRemainingScreenTypes() throws {
        let library = try CurriculumLibrary.load(from: .main)
        let lesson = try XCTUnwrap(library.lesson("sample-screen-types"))
        XCTAssertTrue(lesson.isSample)
        let kinds = Set(lesson.screens.map(\.kindName))
        XCTAssertTrue(kinds.isSuperset(of: ["sortIt", "storyChoice", "countIt"]), "got \(kinds)")
    }

    // MARK: Validation

    func testQuestionWithNoRightAnswerIsRejected() throws {
        let lesson = try decode(lessonJSON(choices: """
        [{"label": "Need", "icon": "thumbs-up"}, {"label": "Want", "icon": "balloon"}]
        """))
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("no choice marked") }, "got \(problems)")
    }

    func testUnknownIconIsRejected() throws {
        let lesson = try decode(lessonJSON(choices: """
        [{"label": "Need", "icon": "not-a-real-picture", "correct": true},
         {"label": "Want", "icon": "balloon"}]
        """))
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("not-a-real-picture") }, "got \(problems)")
    }

    func testLessonMustEndOnACelebration() throws {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test",
         "screens": [{"type": "hello", "penny": "Hi, {name}!"}]}
        """
        let lesson = try decode(json)
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("yay screen") }, "got \(problems)")
    }

    func testMismatchedFileNameIsRejected() throws {
        let lesson = try decode(lessonJSON())
        let problems = lesson.validationProblems(expectedID: "some-other-name", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("they must match") }, "got \(problems)")
    }

    func testCountItCannotAskForMoreCoinsThanItGives() throws {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "countIt", "prompt": "Count", "pennyHint": "Count, {name}",
           "available": 3, "target": 5, "rightMessage": "Yes", "wrongMessage": "Good try"},
          {"type": "yay"}]}
        """
        let lesson = try decode(json)
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("only 3 are available") }, "got \(problems)")
    }

    /// A missing field names itself, so a writer knows what to add.
    func testDecodingErrorNamesTheMissingField() {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "tapToChoose", "pennyHint": "Look, {name}!", "choices": [],
           "rightMessage": "Yes", "wrongMessage": "Good try"}]}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("expected a missing-key error, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "prompt")
        }
    }

    /// Screens without an id get a stable one from their position, so progress
    /// and the retry queue always have something to key on.
    func testScreensWithoutIDsGetPositionalOnes() throws {
        let lesson = try decode(lessonJSON())
        XCTAssertEqual(lesson.screens.first?.id, "hello-1")
        XCTAssertEqual(lesson.screens.last?.id, "yay-3")
    }

    // MARK: Helpers

    private func decode(_ json: String) throws -> Lesson {
        try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))
    }

    private func lessonJSON(choices: String = """
    [{"label": "Need", "icon": "thumbs-up", "correct": true}, {"label": "Want", "icon": "balloon"}]
    """) -> String {
        """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "tapToChoose", "id": "q1", "prompt": "Need or want?",
           "pennyHint": "Look, {name}!", "choices": \(choices),
           "rightMessage": "Yes, {name}!", "wrongMessage": "Good try, {name}!"},
          {"type": "yay"}]}
        """
    }
}
