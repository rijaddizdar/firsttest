//
//  LessonDecoding.swift
//  Decoding + validation for the bundled lesson files.
//
//  Two jobs:
//   1. Turn a JSON screen object into the right `LessonScreen` case, giving
//      screens that don't declare an `id` a stable one from their position.
//   2. Check a decoded lesson makes sense (a Hello first, a Yay! last, every
//      question answerable, every picture actually in the asset catalog) and
//      report every problem at once, naming the file and the screen.
//
//  The point is that a writer who mistypes an icon name or forgets to mark the
//  right answer gets a sentence that says so, not a blank picture in front of a
//  child.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Errors

/// Anything that can go wrong loading content. Messages are written for whoever
/// edits the JSON, so they always name the file.
enum ContentError: LocalizedError {
    case missingCurriculum
    case missingLessonFile(id: String, expectedFile: String)
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decoding(file: String, detail: String)
    case invalid(file: String, problems: [String])

    var errorDescription: String? {
        switch self {
        case .missingCurriculum:
            return "Content/curriculum.json is missing from the app bundle."
        case .missingLessonFile(let id, let file):
            return "curriculum.json lists lesson \"\(id)\", but \(file) is not in the app bundle."
        case .unsupportedSchemaVersion(let found, let supported):
            return "curriculum.json has schemaVersion \(found); this build understands \(supported)."
        case .decoding(let file, let detail):
            return "\(file) could not be read: \(detail)"
        case .invalid(let file, let problems):
            return "\(file) is not a valid lesson:\n" + problems.map { "  • \($0)" }.joined(separator: "\n")
        }
    }
}

// MARK: - Screen decoding

private enum ScreenTypeKey: String, CodingKey { case type, id }

/// The `"type"` values a lesson file may use, one per README section 3 screen.
private enum ScreenKind: String, Decodable, CaseIterable {
    case hello, learn, tapToChoose, sortIt, storyChoice, countIt, yay
}

extension LessonScreen {
    /// Decode one screen. `fallbackIndex` names screens that don't declare an
    /// `id`, so the retry queue and progress always have something to key on.
    init(from decoder: Decoder, fallbackIndex: Int) throws {
        let keyed = try decoder.container(keyedBy: ScreenTypeKey.self)
        let kind = try keyed.decode(ScreenKind.self, forKey: .type)
        let fallbackID = "\(kind.rawValue)-\(fallbackIndex + 1)"

        switch kind {
        case .hello:
            var screen = try HelloScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .hello(screen)
        case .learn:
            var screen = try LearnScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .learn(screen)
        case .tapToChoose:
            var screen = try TapToChooseScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .tapToChoose(screen)
        case .sortIt:
            var screen = try SortItScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .sortIt(screen)
        case .storyChoice:
            var screen = try StoryChoiceScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .storyChoice(screen)
        case .countIt:
            var screen = try CountItScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .countIt(screen)
        case .yay:
            var screen = try YayScreen(from: decoder)
            screen.id = screen.id.isEmpty ? fallbackID : screen.id
            self = .yay(screen)
        }
    }

    /// Human name for messages ("screen 3 (tapToChoose)").
    var kindName: String {
        switch self {
        case .hello:       return "hello"
        case .learn:       return "learn"
        case .tapToChoose: return "tapToChoose"
        case .sortIt:      return "sortIt"
        case .storyChoice: return "storyChoice"
        case .countIt:     return "countIt"
        case .yay:         return "yay"
        }
    }
}

// MARK: - Per-screen Decodable

extension HelloScreen: Decodable {
    private enum CodingKeys: String, CodingKey { case id, penny, pose, continueLabel }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        penny = try c.decode(String.self, forKey: .penny)
        pose = try c.decodeIfPresent(PennyPose.self, forKey: .pose) ?? .wave
        continueLabel = try c.decodeIfPresent(String.self, forKey: .continueLabel) ?? "Let's go!"
    }
}

extension LearnScreen: Decodable {
    private enum CodingKeys: String, CodingKey { case id, title, cards, penny, continueLabel }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decode(String.self, forKey: .title)
        cards = try c.decode([LearnCard].self, forKey: .cards)
        penny = try c.decodeIfPresent(String.self, forKey: .penny)
        continueLabel = try c.decodeIfPresent(String.self, forKey: .continueLabel) ?? "I'm ready"
    }
}

extension TapToChooseScreen: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, prompt, pennyHint, choices, rightMessage, wrongMessage, retryIntro
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        prompt = try c.decode(String.self, forKey: .prompt)
        pennyHint = try c.decode(String.self, forKey: .pennyHint)
        choices = try c.decode([Choice].self, forKey: .choices)
        rightMessage = try c.decode(String.self, forKey: .rightMessage)
        wrongMessage = try c.decode(String.self, forKey: .wrongMessage)
        retryIntro = try c.decodeIfPresent(String.self, forKey: .retryIntro)
    }
}

extension SortItScreen: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, prompt, pennyHint, groups, items, rightMessage, wrongMessage, doneMessage, retryIntro
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        prompt = try c.decode(String.self, forKey: .prompt)
        pennyHint = try c.decode(String.self, forKey: .pennyHint)
        groups = try c.decode([Group].self, forKey: .groups)
        items = try c.decode([Item].self, forKey: .items)
        rightMessage = try c.decode(String.self, forKey: .rightMessage)
        wrongMessage = try c.decode(String.self, forKey: .wrongMessage)
        doneMessage = try c.decode(String.self, forKey: .doneMessage)
        retryIntro = try c.decodeIfPresent(String.self, forKey: .retryIntro)
    }
}

extension StoryChoiceScreen: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, story, storyIcon, prompt, pennyHint, options, rightMessage, wrongMessage, retryIntro
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        story = try c.decode(String.self, forKey: .story)
        storyIcon = try c.decodeIfPresent(String.self, forKey: .storyIcon)
        prompt = try c.decode(String.self, forKey: .prompt)
        pennyHint = try c.decode(String.self, forKey: .pennyHint)
        options = try c.decode([Option].self, forKey: .options)
        rightMessage = try c.decode(String.self, forKey: .rightMessage)
        wrongMessage = try c.decode(String.self, forKey: .wrongMessage)
        retryIntro = try c.decodeIfPresent(String.self, forKey: .retryIntro)
    }
}

extension CountItScreen: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, prompt, pennyHint, available, target, jarIcon, jarLabel, checkLabel,
             rightMessage, wrongMessage, retryIntro
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        prompt = try c.decode(String.self, forKey: .prompt)
        pennyHint = try c.decode(String.self, forKey: .pennyHint)
        available = try c.decode(Int.self, forKey: .available)
        target = try c.decode(Int.self, forKey: .target)
        jarIcon = try c.decodeIfPresent(String.self, forKey: .jarIcon) ?? "jar"
        jarLabel = try c.decodeIfPresent(String.self, forKey: .jarLabel) ?? "The jar"
        checkLabel = try c.decodeIfPresent(String.self, forKey: .checkLabel) ?? "Check my jar"
        rightMessage = try c.decode(String.self, forKey: .rightMessage)
        wrongMessage = try c.decode(String.self, forKey: .wrongMessage)
        retryIntro = try c.decodeIfPresent(String.self, forKey: .retryIntro)
    }
}

extension YayScreen: Decodable {
    private enum CodingKeys: String, CodingKey { case id, title, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Lesson done, {name}!"
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? "You kept trying, and you got it!"
    }
}

// MARK: - Lesson decoding

extension Lesson: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, levelID, title, sample, estimatedMinutes, coins, screens
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        levelID = try c.decode(Int.self, forKey: .levelID)
        title = try c.decode(String.self, forKey: .title)
        isSample = try c.decodeIfPresent(Bool.self, forKey: .sample) ?? false
        estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 3
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 10

        // Screens are decoded one at a time so each can be given a fallback id
        // from its position in the lesson.
        var array = try c.nestedUnkeyedContainer(forKey: .screens)
        var decoded: [LessonScreen] = []
        var index = 0
        while !array.isAtEnd {
            let screenDecoder = try array.superDecoder()
            decoded.append(try LessonScreen(from: screenDecoder, fallbackIndex: index))
            index += 1
        }
        screens = decoded
    }
}

// MARK: - Validation

extension Lesson {
    /// Everything wrong with this lesson, in writer-readable sentences. Empty
    /// means the lesson is playable.
    func validationProblems(expectedID: String, knownLevelIDs: Set<Int>) -> [String] {
        var problems: [String] = []

        if id != expectedID {
            problems.append("\"id\" is \"\(id)\" but the file is named \(expectedID).json — they must match.")
        }
        if !knownLevelIDs.contains(levelID) {
            problems.append("\"levelID\": \(levelID) is not a level in curriculum.json.")
        }
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            problems.append("\"title\" is empty.")
        }
        if coins < 0 { problems.append("\"coins\": \(coins) cannot be negative.") }

        // Structure: Hello first, Yay! last, questions in between.
        guard let first = screens.first, let last = screens.last else {
            return problems + ["\"screens\" is empty. A lesson needs at least a hello and a yay screen."]
        }
        if case .hello = first {} else {
            problems.append("the first screen is \(first.kindName); a lesson opens with a hello screen (README section 3).")
        }
        if case .yay = last {} else {
            problems.append("the last screen is \(last.kindName); a lesson ends with a yay screen (README section 3).")
        }
        if screens.filter({ if case .yay = $0 { return true } else { return false } }).count != 1 {
            problems.append("a lesson has exactly one yay screen.")
        }
        if questionScreens.isEmpty {
            problems.append("there is nothing for the child to answer — add at least one tapToChoose, sortIt, storyChoice or countIt screen.")
        }

        // Duplicate ids would confuse the retry queue and progress.
        let ids = screens.map(\.id)
        let duplicates = Set(ids.filter { id in ids.filter { $0 == id }.count > 1 })
        if !duplicates.isEmpty {
            problems.append("screen ids are repeated: \(duplicates.sorted().joined(separator: ", ")).")
        }

        for (index, screen) in screens.enumerated() {
            let place = "screen \(index + 1) (\(screen.kindName))"
            problems += screen.validationProblems(place: place)
            for icon in screen.iconNames where !ContentArt.exists(icon) {
                problems.append("\(place) asks for the picture \"\(icon)\", which is not in Assets.xcassets/Icons.")
            }
        }
        return problems
    }
}

extension LessonScreen {
    func validationProblems(place: String) -> [String] {
        var problems: [String] = []
        switch self {
        case .hello(let s):
            if s.penny.isEmpty { problems.append("\(place) has no \"penny\" line.") }
            if !s.penny.contains("{name}") {
                problems.append("\(place) should greet the child by name — put {name} in \"penny\" (README section 3).")
            }
        case .learn(let s):
            if s.cards.isEmpty { problems.append("\(place) has no \"cards\"; every screen shows a picture (README section 3).") }
        case .tapToChoose(let s):
            if s.choices.count < 2 || s.choices.count > 3 {
                problems.append("\(place) has \(s.choices.count) choices; use 2 or 3 (README section 3).")
            }
            if !s.choices.contains(where: \.correct) {
                problems.append("\(place) has no choice marked \"correct\": true.")
            }
            if s.choices.filter(\.correct).count > 1 {
                problems.append("\(place) marks more than one choice correct.")
            }
        case .sortIt(let s):
            if s.groups.count < 2 { problems.append("\(place) needs at least 2 groups to sort into.") }
            if s.items.count < 2 { problems.append("\(place) needs at least 2 pictures to sort.") }
            if s.items.count > 6 {
                problems.append("\(place) has \(s.items.count) pictures; keep it to 6 so the tray fits on a phone.")
            }
            let groupIDs = Set(s.groups.map(\.id))
            for item in s.items where !groupIDs.contains(item.groupID) {
                problems.append("\(place) puts \"\(item.id)\" in group \"\(item.groupID)\", which is not one of its groups.")
            }
            for group in s.groups where !s.items.contains(where: { $0.groupID == group.id }) {
                problems.append("\(place) has an empty group \"\(group.id)\" — nothing sorts into it.")
            }
        case .storyChoice(let s):
            if s.options.count < 2 || s.options.count > 3 {
                problems.append("\(place) has \(s.options.count) options; use 2 or 3.")
            }
            if s.options.filter(\.correct).count != 1 {
                problems.append("\(place) needs exactly one option marked \"correct\": true.")
            }
        case .countIt(let s):
            if s.available < 1 { problems.append("\(place) has \"available\": \(s.available); give the child at least 1 coin.") }
            if s.target < 1 { problems.append("\(place) has \"target\": \(s.target); the answer must be at least 1 coin.") }
            if s.target > s.available {
                problems.append("\(place) asks for \(s.target) coins but only \(s.available) are available.")
            }
            // README section 7 rule 8: kid-sized numbers, whole coins.
            if s.available > 20 {
                problems.append("\(place) offers \(s.available) coins; keep counting screens to 20 or fewer (README section 7 rule 8).")
            }
        case .yay(let s):
            if s.title.isEmpty { problems.append("\(place) has an empty \"title\".") }
        }
        return problems
    }
}

// MARK: - Art lookup

/// Does a Fluent Emoji 3D picture with this name exist in the asset catalog?
/// Checked at load so a mistyped icon name is an error a writer can read, not a
/// blank square in front of a child.
enum ContentArt {
    static func exists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        // The macOS SDK is only used for type-checking; assume the art is there.
        return true
        #endif
    }
}
