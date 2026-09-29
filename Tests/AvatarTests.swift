//
//  AvatarTests.swift
//  The rules the avatar builder must not silently break: every combination is
//  a renderable avatar, a headscarf never ends up on the boy look, the choices
//  survive quitting the app, and a profile saved before the builder existed
//  still loads.
//

import XCTest
import SwiftData
@testable import MoneyPals

@MainActor
final class AvatarTests: XCTestCase {

    private var container: ModelContainer!
    private var store: ProgressStore!
    private var library: CurriculumLibrary!

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        store = ProgressStore(context: container.mainContext)
        library = try CurriculumLibrary.load(from: .main)
    }

    // MARK: The choices themselves

    /// README section 6: the headscarf is offered to the girl look only.
    func testTheHeadscarfIsOfferedToTheGirlLookOnly() {
        XCTAssertEqual(Hairstyle.choices(for: .girl).count, 7)
        XCTAssertTrue(Hairstyle.choices(for: .girl).contains(.headscarf))
        XCTAssertEqual(Hairstyle.choices(for: .boy).count, 6)
        XCTAssertFalse(Hairstyle.choices(for: .boy).contains(.headscarf))
    }

    /// Switching a child in a headscarf to the boy look has to put something
    /// else on their head rather than leave an unrenderable pairing behind.
    func testSwitchingAwayFromTheGirlLookReplacesTheHeadscarf() {
        var avatar = Avatar(kind: .girl, hairstyle: .headscarf, skinToneIndex: 3,
                            hairColorIndex: 2, outfitColorIndex: 4)
        avatar.setKind(.boy)
        XCTAssertNotEqual(avatar.hairstyle, .headscarf)
        XCTAssertTrue(Hairstyle.choices(for: .boy).contains(avatar.hairstyle))
        XCTAssertEqual(avatar.skinToneIndex, 3, "everything that still makes sense is kept")
        XCTAssertEqual(avatar.outfitColorIndex, 4)
    }

    /// Switching to the girl look and back leaves an ordinary hairstyle alone.
    func testSwitchingLooksKeepsAHairstyleBothLooksOffer() {
        var avatar = Avatar(kind: .boy, hairstyle: .curly)
        avatar.setKind(.girl)
        XCTAssertEqual(avatar.hairstyle, .curly)
        avatar.setKind(.boy)
        XCTAssertEqual(avatar.hairstyle, .curly)
    }

    /// An index that is out of range — a corrupted row, or a palette that got
    /// shorter — must never crash a child's profile picture.
    func testOutOfRangeChoicesAreBroughtBackIntoThePalette() {
        let high = Avatar(kind: .girl, hairstyle: .long, skinToneIndex: 99,
                          hairColorIndex: 40, outfitColorIndex: 12)
        XCTAssertTrue(Palette.avatarSkinTones.indices.contains(high.skinToneIndex))
        XCTAssertTrue(Palette.avatarHairColors.indices.contains(high.hairColorIndex))
        XCTAssertTrue(Palette.avatarChoices.indices.contains(high.outfitColorIndex))

        let negative = Avatar(kind: .boy, hairstyle: .short, skinToneIndex: -1,
                              hairColorIndex: -7, outfitColorIndex: -3)
        XCTAssertTrue(Palette.avatarSkinTones.indices.contains(negative.skinToneIndex))
        XCTAssertTrue(Palette.avatarHairColors.indices.contains(negative.hairColorIndex))
        XCTAssertTrue(Palette.avatarChoices.indices.contains(negative.outfitColorIndex))
    }

    /// Every one of the 2 x 7 x 6 x 6 x 6 combinations the builder can make has
    /// to be a valid avatar — the drawing reads its colours straight off these.
    func testEveryCombinationTheBuilderCanMakeIsValid() {
        var count = 0
        for kind in AvatarKind.allCases {
            for hairstyle in Hairstyle.choices(for: kind) {
                for skin in Palette.avatarSkinTones.indices {
                    for hair in Palette.avatarHairColors.indices {
                        for outfit in Palette.avatarChoices.indices {
                            let avatar = Avatar(kind: kind, hairstyle: hairstyle,
                                                skinToneIndex: skin, hairColorIndex: hair,
                                                outfitColorIndex: outfit)
                            XCTAssertEqual(avatar.hairstyle, hairstyle, "no choice is silently rewritten")
                            XCTAssertEqual(avatar.skinToneIndex, skin)
                            XCTAssertEqual(avatar.hairColorIndex, hair)
                            XCTAssertEqual(avatar.outfitColorIndex, outfit)
                            XCTAssertFalse(avatar.spokenDescription.isEmpty)
                            count += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(count, 13 * 6 * 6 * 6, "6 boy styles + 7 girl styles, each in every colour")
    }

    /// With a headscarf on, the colour swatches are scarf colours, and VoiceOver
    /// says so instead of talking about hair nobody can see.
    func testAHeadscarfWearsTheColourInsteadOfTheHair() {
        let scarf = Avatar(kind: .girl, hairstyle: .headscarf, hairColorIndex: 1)
        XCTAssertTrue(scarf.hairstyle.isScarf)
        XCTAssertTrue(scarf.spokenDescription.contains("headscarf"))
        XCTAssertFalse(scarf.spokenDescription.contains("hair"))

        let hair = Avatar(kind: .girl, hairstyle: .braids, hairColorIndex: 1)
        XCTAssertTrue(hair.spokenDescription.contains("braids hair"))
    }

    // MARK: Saving

    func testAChildsLookSurvivesQuittingTheApp() throws {
        let chosen = Avatar(kind: .boy, hairstyle: .spiky, skinToneIndex: 5,
                            hairColorIndex: 4, outfitColorIndex: 3)
        let id = store.addKid(name: "Jayden", avatar: chosen)

        // A second store over the same data is what a relaunch looks like.
        let reopened = ProgressStore(context: container.mainContext)
        let kid = try XCTUnwrap(reopened.kids(using: library).first { $0.id == id })
        XCTAssertEqual(kid.avatar, chosen)
    }

    func testChangingTheLookLaterIsSaved() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar(kind: .girl, hairstyle: .long))
        let changed = Avatar(kind: .girl, hairstyle: .headscarf, skinToneIndex: 1,
                             hairColorIndex: 5, outfitColorIndex: 2)
        store.updateKid(id, avatar: changed)

        let kid = try XCTUnwrap(ProgressStore(context: container.mainContext)
            .kids(using: library).first { $0.id == id })
        XCTAssertEqual(kid.avatar, changed)
        XCTAssertEqual(kid.name, "Mia", "changing the look leaves the name alone")
    }

    func testRenamingTrimsSpaceAndNeverBlanksTheName() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.updateKid(id, name: "  Amara  ")
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).name, "Amara")

        store.updateKid(id, name: "   ")
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).name, "Amara",
                       "a child who clears the field keeps the name they had")
    }

    /// The migration case: a profile written before the builder existed knows
    /// only its boy/girl look and outfit colour. It must still load, and keep
    /// the two things it did choose.
    func testAProfileSavedBeforeTheBuilderStillLoads() throws {
        let legacy = KidRecord(name: "Sam", avatarKindRaw: "boy", avatarColorIndex: 4)
        XCTAssertNil(legacy.avatarHairstyleRaw)
        container.mainContext.insert(legacy)
        try container.mainContext.save()

        let kid = try XCTUnwrap(ProgressStore(context: container.mainContext)
            .kids(using: library).first { $0.id == legacy.id })
        XCTAssertEqual(kid.avatar, Avatar.defaultLook(kind: .boy, outfitColorIndex: 4))
        XCTAssertEqual(kid.avatar.kind, .boy)
        XCTAssertEqual(kid.avatar.outfitColorIndex, 4, "the colour they picked is kept")
        XCTAssertTrue(kid.hasFinishedFirstRun,
                      "somebody already learning is never sent back to a welcome screen")
    }

    /// A hairstyle raw value that isn't one of ours (a downgrade, a hand-edited
    /// store) falls back to the default look rather than failing to load.
    func testAnUnknownHairstyleFallsBackToTheDefaultLook() throws {
        let odd = KidRecord(name: "Ada", avatarKindRaw: "girl", avatarColorIndex: 1,
                            avatarHairstyleRaw: "mohawk")
        container.mainContext.insert(odd)
        try container.mainContext.save()

        let kid = try XCTUnwrap(ProgressStore(context: container.mainContext)
            .kids(using: library).first { $0.id == odd.id })
        XCTAssertEqual(kid.avatar, Avatar.defaultLook(kind: .girl, outfitColorIndex: 1))
    }

    // MARK: The child's own first time

    func testAProfileAGrownUpMakesStillGetsTheChildsFirstTime() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        var kid = try XCTUnwrap(store.kids(using: library).first { $0.id == id })
        XCTAssertFalse(kid.hasFinishedFirstRun)

        store.markFirstRunFinished(id)
        kid = try XCTUnwrap(ProgressStore(context: container.mainContext)
            .kids(using: library).first { $0.id == id })
        XCTAssertTrue(kid.hasFinishedFirstRun, "and only once — the map opens straight away after")
    }

    /// A name is a first name or a nickname, not an essay: it has to fit in
    /// Penny's speech bubbles (README section 6 and section 7).
    func testANameIsKeptToOneShortLine() {
        XCTAssertEqual(KidFirstRunView.trimToNameLength("Mia"), "Mia")
        XCTAssertEqual(KidFirstRunView.trimToNameLength("Bartholomew\nSmith"), "Bartholomew Smith")
        XCTAssertEqual(KidFirstRunView.trimToNameLength(String(repeating: "a", count: 50)).count, 20)
    }
}
