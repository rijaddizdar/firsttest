//
//  Avatar.swift
//  What a child's profile picture IS — the four choices from README section 6
//  "Customization", and nothing else.
//
//      boy or girl · hairstyle (7, one of them girls-only) · skin tone (6) ·
//      hair colour (6, read as the SCARF colour when the hairstyle is the
//      headscarf) · outfit colour (6)
//
//  Every choice is an index into a fixed palette or a small enum, so the whole
//  avatar is five tiny values. README section 9 allows exactly this ("avatar and
//  customization choices"); photo uploads, last names and free text are
//  deliberately impossible here.
//
//  How it is DRAWN is AvatarArtwork.swift; how it is CHOSEN is
//  AvatarBuilderView.swift; where it is SAVED is Persistence/Records.swift.
//

import SwiftUI

// MARK: - Boy / girl

enum AvatarKind: String, CaseIterable, Identifiable, Hashable {
    case boy, girl
    var id: String { rawValue }

    var label: String { self == .boy ? "Boy" : "Girl" }
}

// MARK: - Hairstyle

/// The seven ready-made hairstyles. `headscarf` is offered to the girl look
/// only (README section 6); when it is chosen the hair colour is worn by the
/// scarf instead, because no hair shows.
enum Hairstyle: String, CaseIterable, Identifiable, Hashable {
    case short, spiky, curly, long, puffs, braids, headscarf
    var id: String { rawValue }

    var label: String {
        switch self {
        case .short:     return "Short"
        case .spiky:     return "Spiky"
        case .curly:     return "Curly"
        case .long:      return "Long"
        case .puffs:     return "Puffs"
        case .braids:    return "Braids"
        case .headscarf: return "Headscarf"
        }
    }

    /// The styles offered for a look. Only the girl look offers the headscarf.
    static func choices(for kind: AvatarKind) -> [Hairstyle] {
        kind == .girl ? allCases : allCases.filter { $0 != .headscarf }
    }

    /// True when the hair colour swatches are really scarf colours.
    var isScarf: Bool { self == .headscarf }
}

// MARK: - The avatar itself

/// One child's look. Five small choices; no free-typed anything.
struct Avatar: Equatable, Hashable {
    var kind: AvatarKind
    var hairstyle: Hairstyle
    /// Index into `Palette.avatarSkinTones`.
    var skinToneIndex: Int
    /// Index into `Palette.avatarHairColors`, or `Palette.avatarScarfColors`
    /// when the hairstyle is the headscarf.
    var hairColorIndex: Int
    /// Index into `Palette.avatarChoices` — the outfit, and the tint of the
    /// badge ring the avatar sits in.
    var outfitColorIndex: Int

    init(kind: AvatarKind = .girl,
         hairstyle: Hairstyle = .long,
         skinToneIndex: Int = 2,
         hairColorIndex: Int = 0,
         outfitColorIndex: Int = 0) {
        self.kind = kind
        self.hairstyle = hairstyle
        self.skinToneIndex = skinToneIndex
        self.hairColorIndex = hairColorIndex
        self.outfitColorIndex = outfitColorIndex
        normalise()
    }

    /// Keep every field inside its palette, and keep the headscarf off the boy
    /// look. Called after any change, so an avatar value is never unrenderable
    /// however it was built (including from an older saved profile).
    mutating func normalise() {
        skinToneIndex = Self.wrap(skinToneIndex, Palette.avatarSkinTones.count)
        hairColorIndex = Self.wrap(hairColorIndex, Palette.avatarHairColors.count)
        outfitColorIndex = Self.wrap(outfitColorIndex, Palette.avatarChoices.count)
        if !Hairstyle.choices(for: kind).contains(hairstyle) {
            hairstyle = Self.defaultHairstyle(for: kind)
        }
    }

    private static func wrap(_ index: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let wrapped = index % count
        return wrapped < 0 ? wrapped + count : wrapped
    }

    /// Switching boy/girl keeps everything that still makes sense and only
    /// moves the hairstyle when the current one isn't offered.
    mutating func setKind(_ newKind: AvatarKind) {
        kind = newKind
        normalise()
    }

    static func defaultHairstyle(for kind: AvatarKind) -> Hairstyle {
        kind == .boy ? .short : .long
    }

    // MARK: Colours

    var skinTone: Color { Palette.avatarSkinTones[skinToneIndex] }
    var skinShade: Color { Palette.avatarSkinShades[skinToneIndex] }
    var hairColor: Color {
        hairstyle.isScarf ? Palette.avatarScarfColors[hairColorIndex]
                          : Palette.avatarHairColors[hairColorIndex]
    }
    var outfitColor: Color { Palette.avatarChoices[outfitColorIndex] }

    // MARK: Defaults

    /// The look a profile starts with, and the one an older saved profile — one
    /// made before the builder existed — is shown with. It only ever knew the
    /// boy/girl look and an outfit colour, so those are kept and the rest takes
    /// a friendly middle default.
    static func defaultLook(kind: AvatarKind, outfitColorIndex: Int) -> Avatar {
        Avatar(kind: kind,
               hairstyle: defaultHairstyle(for: kind),
               skinToneIndex: 2,
               hairColorIndex: 0,
               outfitColorIndex: outfitColorIndex)
    }

    // MARK: VoiceOver

    /// Read out wherever the avatar stands in for a child, and as the live
    /// preview's label in the builder. Plain words a child would use.
    var spokenDescription: String {
        let skin = "skin tone \(skinToneIndex + 1)"
        let outfit = Palette.avatarColorNames[outfitColorIndex]
        if hairstyle.isScarf {
            let scarf = Palette.avatarScarfColorNames[hairColorIndex]
            return "\(kind.label), \(skin), \(scarf) headscarf, \(outfit) top"
        }
        let hair = Palette.avatarHairColorNames[hairColorIndex]
        return "\(kind.label), \(skin), \(hair) \(hairstyle.label.lowercased()) hair, \(outfit) top"
    }
}
