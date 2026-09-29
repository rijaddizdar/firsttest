//
//  AvatarArtwork.swift
//  The child's profile picture, drawn from layered SwiftUI shapes — no photos
//  (README section 9 forbids them) and no bitmaps, so every one of the
//  2 × 7 × 6 × 6 × 6 combinations renders and stays crisp at any size.
//
//  Everything is laid out in a fixed 100 × 100 DESIGN SPACE and then scaled to
//  whatever the caller asks for, so the 40pt badge in the grown-up area and the
//  96pt tile on "Who's learning?" are the same picture, not two drawings that
//  drift apart. The numbers below are therefore design-space units, not points.
//
//      head    centre (50, 46), 54 × 58   eyes y 50   mouth y 61
//      neck    y 67…89                    shoulders   y 78 down
//      hair    may reach y 10 above the head and y 92 below it
//
//  Style follows the Penny Design System: flat fills, no gradients, no shadow
//  (Penny's speech bubble is the app's only shadow), palette from Theme.swift.
//

import SwiftUI

// MARK: - The badge (what the rest of the app uses)

/// A child's avatar in the round badge the app shows it in: a soft tinted disc,
/// a 3px ring in the outfit colour, and the child inside it.
///
/// This replaces the SF Symbol placeholder that stood in for the avatar before
/// the builder existed; every place a kid is shown — "Who's learning?", the map
/// header, the grown-up dashboard — uses it.
struct AvatarBadge: View {
    let avatar: Avatar
    var size: CGFloat = 64
    /// Nil keeps the default spoken description; pass a name to say who it is.
    var spokenName: String?

    var body: some View {
        ZStack {
            Circle().fill(avatar.outfitColor.opacity(0.14))
            // Drawn at the design size and scaled. Everything inside is a
            // vector shape and nothing is flattened with `drawingGroup`, so
            // scaling UP — the 132pt preview in the builder — stays sharp.
            AvatarFigure(avatar: avatar)
                .frame(width: designSize, height: designSize)
                .scaleEffect(size / designSize)
                .frame(width: size, height: size)
                .clipShape(Circle())
            Circle().stroke(avatar.outfitColor, lineWidth: Border.avatar)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(spokenName.map { "\($0), \(avatar.spokenDescription)" }
                            ?? avatar.spokenDescription)
    }
}

/// The design space every part below is drawn in.
private let designSize: CGFloat = 100

// MARK: - The figure

/// Head and shoulders, drawn back to front. Kept separate from `AvatarBadge` so
/// the builder can show the same child without the ring around them.
struct AvatarFigure: View {
    let avatar: Avatar

    var body: some View {
        ZStack {
            shoulders                   // the top the child is wearing
            hairBehindHead              // the volume that sits behind the head
            neck
            head
            if showsEars { ears }
            face
            hairInFrontOfHead           // fringe, spikes, scarf
        }
        .frame(width: designSize, height: designSize)
    }

    private var style: Hairstyle { avatar.hairstyle }
    /// Ears show only where hair doesn't cover them.
    private var showsEars: Bool { [.short, .spiky, .curly, .puffs].contains(style) }

    // MARK: Body

    private var shoulders: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(avatar.outfitColor)
                .frame(width: 82, height: 52)
                .position(x: 50, y: 104)
            neckline
        }
    }

    /// The one place the boy and girl looks differ apart from the hairstyle,
    /// so the two can still be told apart when both wear short hair: a scooped
    /// neckline, or a straight crew neck with a collar notch.
    @ViewBuilder
    private var neckline: some View {
        if avatar.kind == .girl {
            Ellipse()
                .fill(avatar.skinShade)
                .frame(width: 26, height: 13)
                .position(x: 50, y: 83)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(avatar.outfitColor.opacity(0.55))
                .frame(width: 26, height: 7)
                .position(x: 50, y: 88)
        }
    }

    private var neck: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(avatar.skinShade)
            .frame(width: 19, height: 22)
            .position(x: 50, y: 78)
    }

    // MARK: Head and face

    private var head: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(avatar.skinTone)
            .frame(width: 54, height: 58)
            .position(x: 50, y: 46)
    }

    private var ears: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Circle()
                .fill(avatar.skinTone)
                .frame(width: 13, height: 13)
                .overlay(
                    Circle().fill(avatar.skinShade.opacity(0.55))
                        .frame(width: 5, height: 5)
                )
                .position(x: 50 + side * 27, y: 51)
        }
    }

    private var face: some View {
        ZStack {
            // Cheeks — a warm touch that keeps the face from reading flat.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(Palette.copper.opacity(0.22))
                    .frame(width: 11, height: 6)
                    .position(x: 50 + side * 16, y: 58)
            }

            // Brows sit in the hair colour, except under a headscarf, where the
            // "hair" colour is really the scarf and would paint teal eyebrows.
            // Gentle upward arcs, not straight bars: a straight brow this close
            // to the eye reads as a scowl at badge size.
            ForEach([-1.0, 1.0], id: \.self) { side in
                let centre = 50 + side * 10.5
                Path { path in
                    path.move(to: CGPoint(x: centre - 4.8, y: 41.6))
                    path.addQuadCurve(to: CGPoint(x: centre + 4.8, y: 41.6),
                                      control: CGPoint(x: centre, y: 38.2))
                }
                .stroke(style.isScarf ? Palette.ink.opacity(0.45) : avatar.hairColor,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }

            eyes

            // A plain, calm smile. Never a grin, never teeth — Penny's world is
            // warm and low-key (README section 2).
            Path { path in
                path.move(to: CGPoint(x: 43, y: 60))
                path.addQuadCurve(to: CGPoint(x: 57, y: 60), control: CGPoint(x: 50, y: 67))
            }
            .stroke(Palette.ink.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private var eyes: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ZStack {
                Circle()
                    .fill(Palette.ink)
                    .frame(width: 7.6, height: 7.6)
                Circle()
                    .fill(.white)
                    .frame(width: 2.6, height: 2.6)
                    .offset(x: 1.4, y: -1.6)
                // The girl look adds a lash tick at the outer corner.
                if avatar.kind == .girl {
                    Capsule()
                        .fill(Palette.ink)
                        .frame(width: 4.4, height: 1.9)
                        .rotationEffect(.degrees(side > 0 ? -16 : 16))
                        .offset(x: side * 5.6, y: -2.4)
                }
            }
            .position(x: 50 + side * 10.5, y: 50)
        }
    }

    // MARK: Hair

    /// Volume the head sits in front of: the length of long hair, the mass of
    /// puffs and curls, the braids, and the body of a headscarf.
    @ViewBuilder
    private var hairBehindHead: some View {
        switch style {
        case .long:
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(avatar.hairColor)
                .frame(width: 68, height: 78)
                .position(x: 50, y: 52)

        case .braids:
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(avatar.hairColor)
                .frame(width: 62, height: 54)
                .position(x: 50, y: 42)
            // The braids themselves, kept inboard of x 20 / 80 so the badge's
            // circle doesn't slice their ends off.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(avatar.hairColor)
                    .frame(width: 13, height: 36)
                    .position(x: 50 + side * 28, y: 62)
                // The bobble on the end, in the outfit colour so the child's
                // pick shows up twice.
                Circle()
                    .fill(avatar.outfitColor)
                    .frame(width: 11, height: 11)
                    .position(x: 50 + side * 28, y: 80)
            }

        case .puffs:
            // Two clear balls above the ears. They only read as two if the cap
            // under them hugs the head, so puffs wear a narrower cap below.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle()
                    .fill(avatar.hairColor)
                    .frame(width: 32, height: 32)
                    .position(x: 50 + side * 28, y: 26)
            }

        case .curly:
            // A ring of overlapping circles: curls read as bumps, not an outline.
            ForEach(Array(curlPositions.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(avatar.hairColor)
                    .frame(width: 24, height: 24)
                    .position(x: point.x, y: point.y)
            }

        case .headscarf:
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(avatar.hairColor)
                .frame(width: 70, height: 80)
                .position(x: 50, y: 47)

        case .short, .spiky:
            EmptyView()
        }
    }

    /// What covers the top of the head: the cap every hairstyle wears, plus
    /// whatever that style adds on top of it.
    @ViewBuilder
    private var hairInFrontOfHead: some View {
        switch style {
        case .short:
            // Swept to one side rather than a symmetrical bowl: a hairline that
            // arcs the same both ways reads as a helmet at badge size.
            cap(sideY: 40, dipY: 35, tilt: 16)

        case .spiky:
            cap(sideY: 41, dipY: 35, tilt: 10)
            // Wide, overlapping bases sunk INTO the cap. Narrow ones perched on
            // the rim left a scalloped band that read as a paper crown.
            ForEach(Array(spikes.enumerated()), id: \.offset) { _, spike in
                let base = CGPoint(x: 50 + spike.dx, y: hairTopY(dx: spike.dx) + 8)
                Path { path in
                    path.move(to: CGPoint(x: base.x - 8, y: base.y))
                    path.addLine(to: CGPoint(x: base.x + spike.dx * 0.42,
                                             y: base.y - spike.height))
                    path.addLine(to: CGPoint(x: base.x + 8, y: base.y))
                    path.closeSubpath()
                }
                .fill(avatar.hairColor)
            }

        case .curly:
            cap(sideY: 49, dipY: 39)

        case .long:
            cap(sideY: 54, dipY: 44)

        case .puffs:
            // Narrow enough to hug the skull, so the two puffs behind it stay
            // two puffs instead of merging into one mass.
            hairShape(width: 55, height: 60, centreY: 44, corner: 25,
                      sideY: 42, dipY: 45)

        case .braids:
            cap(sideY: 52, dipY: 43)

        case .headscarf:
            scarf
        }
    }

    /// The hair that sits ON the head: the same rounded silhouette as the head,
    /// a little larger all round, cut off by a hairline.
    ///
    /// Drawing it as its own arc instead made every style read as a helmet —
    /// the hair has to follow the skull it is on.
    ///
    /// - Parameters:
    ///   - sideY: how far down the temples the hair reaches.
    ///   - dipY:  where the hairline sits in the MIDDLE. Above the brows (38)
    ///            for a tidy cut, below them (44) for a full fringe.
    private func cap(sideY: CGFloat, dipY: CGFloat, tilt: CGFloat = 0) -> some View {
        hairShape(width: Self.hairWidth, height: Self.hairHeight,
                  centreY: Self.hairCentreY, corner: Self.hairCorner,
                  sideY: sideY, dipY: dipY, tilt: tilt)
    }

    /// A mass of hair (or scarf) cut off by a hairline. Styles that need a
    /// different bulk — the narrow cap under puffs, the scarf's wider band —
    /// give their own size instead of the default cap's.
    private func hairShape(width: CGFloat, height: CGFloat, centreY: CGFloat,
                           corner: CGFloat, sideY: CGFloat, dipY: CGFloat,
                           tilt: CGFloat = 0) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(avatar.hairColor)
            .frame(width: width, height: height)
            .position(x: 50, y: centreY)
            .mask(hairline(sideY: sideY, dipY: dipY, tilt: tilt))
    }

    /// Everything above the hairline. The hairline runs from `sideY` at both
    /// temples and arcs to `dipY` in the middle; `tilt` slides the low point of
    /// that arc sideways, which is what turns a symmetrical bowl into a fringe
    /// swept to one side.
    private func hairline(sideY: CGFloat, dipY: CGFloat, tilt: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -10, y: -10))
            path.addLine(to: CGPoint(x: 110, y: -10))
            path.addLine(to: CGPoint(x: 110, y: sideY))
            // A quadratic's midpoint is a quarter of each end plus half the
            // control, so this control puts the middle of the curve on dipY.
            path.addQuadCurve(to: CGPoint(x: -10, y: sideY),
                              control: CGPoint(x: 50 + tilt, y: 2 * dipY - sideY))
            path.closeSubpath()
        }
    }

    /// The headscarf: the cap, panels down both sides of the face, a piece
    /// under the chin and a small knot. No hair shows, so the "hair colour" the
    /// child picked is worn by the scarf (README section 6).
    private var scarf: some View {
        ZStack {
            // The band across the forehead, cut from the same mass that sits
            // behind the head, so front and back are one piece of cloth.
            hairShape(width: 70, height: 82, centreY: 47, corner: 32,
                      sideY: 50, dipY: 35)
            // Panels down both sides. Narrow and well out, or the face ends up
            // peering through a letterbox.
            ForEach([-1.0, 1.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(avatar.hairColor)
                    .frame(width: 11, height: 44)
                    .position(x: 50 + side * 30, y: 56)
            }
            // Under the chin, starting at the jaw rather than over the mouth.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(avatar.hairColor)
                .frame(width: 52, height: 22)
                .position(x: 50, y: 85)
            Circle()
                .fill(avatar.hairColor)
                .frame(width: 13, height: 13)
                .position(x: 73, y: 84)
        }
    }

    // MARK: Where the top of the hair is
    //
    // Spikes and curls have to sit ON the cap, so their positions are read off
    // the cap's own rounded-rectangle outline rather than hand-placed to look
    // right in one screenshot and drift in the next.

    private static let hairWidth: CGFloat = 61
    private static let hairHeight: CGFloat = 64
    private static let hairCentreY: CGFloat = 42
    private static let hairCorner: CGFloat = 27

    /// The y of the cap's top edge, `dx` units left or right of the middle.
    private func hairTopY(dx: CGFloat) -> CGFloat {
        let halfWidth = Self.hairWidth / 2
        let halfHeight = Self.hairHeight / 2
        let radius = Self.hairCorner
        let straight = halfWidth - radius          // the flat part of the top
        let top = Self.hairCentreY - halfHeight
        let offset = abs(dx)
        guard offset > straight else { return top }
        let into = min(offset - straight, radius)  // how far into the corner
        let cornerCentreY = top + radius
        return cornerCentreY - sqrt(max(0, radius * radius - into * into))
    }

    /// Where each spike sits and how tall it is. Uneven on purpose.
    private var spikes: [(dx: CGFloat, height: CGFloat)] {
        [(-21, 15), (-7, 22), (7, 20), (21, 14)]
    }

    private var curlPositions: [CGPoint] {
        [-27, -18.5, -7, 3.5, 14.5, 24].map { dx in
            CGPoint(x: 50 + dx, y: hairTopY(dx: dx) + 4)
        }
    }
}

#if DEBUG
#Preview("Every hairstyle") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(AvatarKind.allCases) { kind in
                Text(kind.label).font(.sectionTitle)
                HStack(spacing: 12) {
                    ForEach(Hairstyle.choices(for: kind)) { style in
                        VStack(spacing: 6) {
                            AvatarBadge(avatar: Avatar(kind: kind, hairstyle: style,
                                                       skinToneIndex: 2, hairColorIndex: 1,
                                                       outfitColorIndex: 0), size: 84)
                            Text(style.label).font(.caption)
                        }
                    }
                }
            }
            Text("Small sizes").font(.sectionTitle)
            HStack(spacing: 12) {
                ForEach([40.0, 44.0, 56.0, 72.0, 96.0], id: \.self) { size in
                    AvatarBadge(avatar: Avatar(kind: .girl, hairstyle: .braids,
                                               skinToneIndex: 4, hairColorIndex: 0,
                                               outfitColorIndex: 3), size: size)
                }
            }
        }
        .padding()
    }
    .background(Palette.cream)
}
#endif
