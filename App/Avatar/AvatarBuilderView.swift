//
//  AvatarBuilderView.swift
//  "Make it yours!" — the avatar builder from README section 6.
//
//  One reusable control, not a screen: the child's first time uses it, the
//  grown-up's "Add a kid" uses it, and "Make it yours!" from the map header
//  uses it, so what is made really is what is shown everywhere.
//
//  Pictures first, words second (README section 7 rule 3): the hairstyle row is
//  seven small drawings of THIS child wearing each style, in the colours they
//  have already picked, and every colour row is swatches. Every control still
//  carries a spoken label, because a picture alone says nothing to VoiceOver.
//

import SwiftUI

struct AvatarBuilderView: View {
    @Binding var avatar: Avatar
    /// How big the live preview is. Smaller inside the grown-up's Add-a-kid
    /// screen, which has a name field and a button to fit as well.
    var previewSize: CGFloat = 112

    var body: some View {
        // Tight spacing on purpose: all five groups of choices have to be
        // reachable without the last one hiding behind the button.
        VStack(spacing: 16) {
            AvatarBadge(avatar: avatar, size: previewSize)
                .accessibilityLabel("Your look: \(avatar.spokenDescription)")
                .animation(.easeInOut(duration: Motion.press), value: avatar)

            kindPicker
            hairstyleRow
            swatchRow(title: "Skin",
                      colors: Palette.avatarSkinTones,
                      names: (1...Palette.avatarSkinTones.count).map { "Skin tone \($0)" },
                      selection: avatar.skinToneIndex) { avatar.skinToneIndex = $0 }
            swatchRow(title: avatar.hairstyle.isScarf ? "Scarf colour" : "Hair colour",
                      colors: avatar.hairstyle.isScarf ? Palette.avatarScarfColors : Palette.avatarHairColors,
                      names: avatar.hairstyle.isScarf ? Palette.avatarScarfColorNames : Palette.avatarHairColorNames,
                      selection: avatar.hairColorIndex) { avatar.hairColorIndex = $0 }
            swatchRow(title: "Clothes",
                      colors: Palette.avatarChoices,
                      names: Palette.avatarColorNames,
                      selection: avatar.outfitColorIndex) { avatar.outfitColorIndex = $0 }
        }
    }

    // MARK: Boy / girl

    private var kindPicker: some View {
        Picker("Boy or girl", selection: Binding(
            get: { avatar.kind },
            // Going from girl to boy with a headscarf on has to put something
            // else on the child's head; `setKind` is the only place that rule
            // lives, so the builder can't get it subtly different.
            set: { avatar.setKind($0) }
        )) {
            ForEach(AvatarKind.allCases) { kind in Text(kind.label).tag(kind) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    // MARK: Hairstyle

    private var hairstyleRow: some View {
        VStack(spacing: 8) {
            rowTitle("Hair")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Hairstyle.choices(for: avatar.kind)) { style in
                        hairstyleButton(style)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)   // room for the selected ring
            }
        }
    }

    private func hairstyleButton(_ style: Hairstyle) -> some View {
        let isSelected = avatar.hairstyle == style
        var preview = avatar
        preview.hairstyle = style
        // A scarf and hair read the same index off different palettes, so the
        // thumbnail shows the colour that style would actually wear.
        return Button {
            avatar.hairstyle = style
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(.white)
                    AvatarFigure(avatar: preview)
                        .frame(width: 100, height: 100)
                        .scaleEffect(0.58)
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                    Circle().stroke(isSelected ? Palette.teal : Palette.borderField,
                                    lineWidth: isSelected ? Border.choice : Border.field)
                }
                .frame(width: 58, height: 58)

                Text(style.label)
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Palette.teal : Palette.textSoft)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(style.label) hair")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Colour rows

    private func swatchRow(title: String,
                           colors: [Color],
                           names: [String],
                           selection: Int,
                           onPick: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 8) {
            rowTitle(title)
            HStack(spacing: 12) {
                ForEach(colors.indices, id: \.self) { index in
                    Button { onPick(index) } label: {
                        Circle()
                            .fill(colors[index])
                            .frame(width: 40, height: 40)
                            // A hairline on every swatch, so the palest skin
                            // tone is still a circle against the cream page.
                            .overlay(Circle().stroke(Palette.ink.opacity(0.15), lineWidth: Border.hairline))
                            .overlay(
                                Circle().stroke(Palette.teal,
                                                lineWidth: selection == index ? Border.choice : 0)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(title): \(names[index])")
                    .accessibilityAddTraits(selection == index ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private func rowTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textSoft)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - "Make it yours!" as a screen

/// The builder on its own page, opened from a child's map header so they can
/// change their look whenever they like (README section 6: "Children can change
/// all of this at any time").
struct EditAvatarView: View {
    @EnvironmentObject private var app: AppState
    @State private var avatar = Avatar()
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Text("Make it yours!")
                        .font(.screenTitle)
                        .foregroundStyle(Palette.textHeading)
                        .multilineTextAlignment(.center)

                    AvatarBuilderView(avatar: $avatar)
                }
                // Sits a little below the top of the screen rather than centred.
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Button("Done") {
                if let id = app.selectedKidID { app.updateKid(id, avatar: avatar) }
                app.route = .lessonMap
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lessonContentWidth()
        .kidPageBackground()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            avatar = app.selectedKid?.avatar ?? Avatar()
        }
    }
}

#if DEBUG
private struct BuilderPreviewHost: View {
    @State private var avatar = Avatar(kind: .girl, hairstyle: .puffs,
                                       skinToneIndex: 3, hairColorIndex: 1, outfitColorIndex: 2)
    var body: some View {
        ScrollView { AvatarBuilderView(avatar: $avatar).padding(.vertical, 24) }
            .background(Palette.cream)
    }
}

#Preview("Builder") { BuilderPreviewHost() }
#Preview("Make it yours!") { EditAvatarView().environmentObject(AppState.preview()) }
#endif
