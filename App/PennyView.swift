//
//  PennyView.swift
//  A 2D Penny the Pangolin, drawn entirely from SwiftUI shapes + gradients.
//
//  The real app will ship a commissioned glossy 3D Penny (README section 8);
//  this vector stand-in aims for the same warm, glossy character — a rounded
//  copper body with a fan of shiny coin-scales, a peach face with big blinking
//  eyes and rosy cheeks, and her teal knit scarf. No external art, no 3D, no
//  third-party packages.
//
//  Motion (all disabled under Reduce Motion, which holds a calm still pose):
//    • idle   — gentle breathe, occasional blink + look-around
//    • wave   — idle plus a waving arm and a friendly greeting
//    • cheer  — a happy hop, both arms up, closed "^^" eyes, coins handled by
//               the CoinBurst overlay in the lesson
//    • curl   — rolls into a coin ball, then a single eye peeks out
//

import SwiftUI

/// Penny's expression for a given moment (README section 2 "How Penny moves").
enum PennyMood {
    case idle       // breathing, blinking, looking around
    case cheer      // celebrate: hops, arms up, coins fly
    case curl       // rolls into a coin ball after a wrong answer, then peeks out
    case wave       // greeting
}

struct PennyView: View {
    var mood: PennyMood = .idle
    var size: CGFloat = 160
    var scarfColor: Color = Palette.teal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Idle drivers.
    @State private var breathe = false      // slow breathe / float
    @State private var eyesClosed = false   // blink
    @State private var lookX: CGFloat = 0   // pupils drift left/right
    @State private var appeared = false     // gate motion until on screen

    // Cheer / wave / curl drivers.
    @State private var hop = false          // cheer bounce
    @State private var wave = false         // waving arm
    @State private var curled = false       // rolled into a ball
    @State private var peek = false         // eye peeking out of the ball

    // Blink / look scheduling.
    @State private var blinkWork: DispatchWorkItem?
    @State private var lookWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            if mood == .curl {
                curledPenny
            } else {
                uprightPenny
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(bodyScale, anchor: .bottom)
        .offset(y: floatOffset)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .onAppear { startMotion() }
        .onDisappear { stopTimers() }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Upright pose

    private var uprightPenny: some View {
        ZStack {
            feet
            armsBehind          // resting / cheering arms drawn behind the body
            bodyShape
            bellyPatch
            scaleFan            // pangolin coin-scales over the crown / back
            faceGroup
            scarf
            armFront            // the waving / cheering front arm
        }
        .frame(width: size, height: size)
    }

    // Feet peeking under the body.
    private var feet: some View {
        HStack(spacing: size * 0.14) {
            foot; foot
        }
        .offset(y: size * 0.40)
    }
    private var foot: some View {
        Ellipse()
            .fill(LinearGradient(colors: [Palette.copper, Palette.copperDeep],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.16, height: size * 0.10)
    }

    // Glossy copper body — an egg with a warm radial sheen.
    private var bodyShape: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Palette.copperLight, Palette.copper, Palette.copperDeep],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: size * 0.02,
                    endRadius: size * 0.62
                )
            )
            .overlay(
                // Soft specular highlight, upper-left.
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: size * 0.22, height: size * 0.15)
                    .blur(radius: size * 0.03)
                    .offset(x: -size * 0.14, y: -size * 0.16)
            )
            .frame(width: size * 0.66, height: size * 0.80)
            .offset(y: size * 0.04)
    }

    // Lighter peach belly.
    private var bellyPatch: some View {
        Ellipse()
            .fill(
                LinearGradient(colors: [Palette.peach, Palette.peachDeep],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: size * 0.40, height: size * 0.46)
            .offset(y: size * 0.16)
            .opacity(0.95)
    }

    // A fan of overlapping coin-scales arcing over Penny's crown — her signature.
    private var scaleFan: some View {
        ZStack {
            // Back row (larger, behind the head) then front row (smaller, on top).
            scaleRow(count: 5, radius: size * 0.30, y: -size * 0.14, scale: 1.0, tint: 0.0)
            scaleRow(count: 4, radius: size * 0.24, y: -size * 0.25, scale: 0.86, tint: 0.06)
            scaleRow(count: 3, radius: size * 0.17, y: -size * 0.33, scale: 0.72, tint: 0.12)
        }
    }

    private func scaleRow(count: Int, radius: CGFloat, y: CGFloat,
                          scale: CGFloat, tint: Double) -> some View {
        // Spread the scales across a shallow arc over the top of the head.
        let spread = Double.pi * 0.62
        return ForEach(0..<count, id: \.self) { i in
            let t = count == 1 ? 0.5 : Double(i) / Double(count - 1)
            let angle = -Double.pi/2 - spread/2 + spread * t
            CoinScale(highlight: tint)
                .frame(width: size * 0.20 * scale, height: size * 0.24 * scale)
                .rotationEffect(.radians(angle + Double.pi/2))
                .offset(x: cos(angle) * radius, y: y + sin(angle) * radius * 0.5)
        }
    }

    // MARK: Face

    private var faceGroup: some View {
        ZStack {
            // Peach face disc.
            Circle()
                .fill(
                    RadialGradient(colors: [Palette.peach.lighter(0.2), Palette.peach, Palette.peachDeep],
                                   center: UnitPoint(x: 0.4, y: 0.35),
                                   startRadius: 1, endRadius: size * 0.28)
                )
                .frame(width: size * 0.46, height: size * 0.44)

            // Rosy cheeks.
            HStack(spacing: size * 0.24) {
                cheek; cheek
            }
            .offset(y: size * 0.05)

            // Eyes.
            HStack(spacing: size * 0.13) {
                eye; eye
            }
            .offset(y: -size * 0.02)

            // Nose + smile.
            nose.offset(y: size * 0.075)
            smile.offset(y: size * 0.115)
        }
        .offset(y: -size * 0.10)
    }

    private var cheek: some View {
        Circle()
            .fill(Color(hex: 0xF19A76).opacity(0.45))
            .frame(width: size * 0.085, height: size * 0.065)
            .blur(radius: size * 0.006)
    }

    private var eye: some View {
        Group {
            if mood == .cheer && !reduceMotion {
                // Happy closed "^" eyes while cheering.
                HappyEye()
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                    .frame(width: size * 0.11, height: size * 0.07)
            } else {
                ZStack {
                    Circle().fill(.white)
                        .frame(width: size * 0.115, height: size * 0.115)
                    Circle().fill(Palette.tealDeep)
                        .frame(width: size * 0.075, height: size * 0.075)
                        .offset(x: lookX * size * 0.02)
                    Circle().fill(Palette.ink)
                        .frame(width: size * 0.045, height: size * 0.045)
                        .offset(x: lookX * size * 0.02)
                    // Catch-light glint.
                    Circle().fill(.white)
                        .frame(width: size * 0.028, height: size * 0.028)
                        .offset(x: size * 0.018 + lookX * size * 0.02, y: -size * 0.016)
                }
                .frame(width: size * 0.115, height: size * 0.115)
                // Blink squashes the eye vertically.
                .scaleEffect(x: 1, y: eyesClosed ? 0.08 : 1, anchor: .center)
                .overlay(
                    // Eyelid line while blinking.
                    Capsule().fill(Palette.ink)
                        .frame(width: size * 0.11, height: size * 0.02)
                        .opacity(eyesClosed ? 1 : 0)
                )
            }
        }
    }

    private var nose: some View {
        Ellipse()
            .fill(LinearGradient(colors: [Palette.copperDeep, Palette.ink.opacity(0.8)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.06, height: size * 0.045)
    }

    private var smile: some View {
        Smile()
            .stroke(Palette.copperDeep, style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
            .frame(width: mood == .cheer ? size * 0.15 : size * 0.10,
                   height: mood == .cheer ? size * 0.06 : size * 0.035)
    }

    // MARK: Scarf

    private var scarf: some View {
        ZStack {
            // Main band.
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(
                    LinearGradient(colors: [scarfColor.lighter(0.12), scarfColor, scarfColor.darker(0.12)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.56, height: size * 0.135)
                .overlay(ribbing.mask(
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .frame(width: size * 0.56, height: size * 0.135)
                ))

            // Hanging end with a little fringe.
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                    .fill(
                        LinearGradient(colors: [scarfColor, scarfColor.darker(0.14)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.11, height: size * 0.16)
                HStack(spacing: size * 0.012) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(scarfColor.darker(0.14))
                            .frame(width: size * 0.02, height: size * 0.04)
                    }
                }
                .offset(y: -size * 0.005)
            }
            .offset(x: size * 0.20, y: size * 0.11)
        }
        .offset(y: size * 0.10)
    }

    // Vertical knit ribbing hint on the scarf.
    private var ribbing: some View {
        HStack(spacing: size * 0.028) {
            ForEach(0..<11, id: \.self) { _ in
                Rectangle().fill(Color.white.opacity(0.10))
                    .frame(width: size * 0.008)
            }
        }
    }

    // MARK: Arms

    // Resting / cheering arms behind the body.
    private var armsBehind: some View {
        HStack {
            arm(side: -1)
            Spacer()
            arm(side: 1)
        }
        .frame(width: size * 0.72)
        .offset(y: size * 0.06)
    }

    private func arm(side: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Palette.copperLight, Palette.copper],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.11, height: size * 0.24)
            .rotationEffect(.degrees(armAngle(side: side)), anchor: .top)
    }

    // The front (waving) arm, only meaningful for wave / cheer.
    private var armFront: some View {
        Capsule()
            .fill(LinearGradient(colors: [Palette.copperLight, Palette.copper],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.10, height: size * 0.22)
            .offset(x: size * 0.30, y: -size * 0.04)
            .rotationEffect(.degrees(waveAngle), anchor: .bottom)
            .opacity(mood == .wave ? 1 : 0)
    }

    private func armAngle(side: CGFloat) -> Double {
        guard appeared else { return Double(side) * 8 }
        if mood == .cheer && (hop || reduceMotion) {
            return Double(side) * 145   // both arms thrown up
        }
        return Double(side) * 10        // relaxed
    }

    // MARK: - Curl-up pose

    private var curledPenny: some View {
        ZStack {
            // Coin ball body.
            Circle()
                .fill(
                    RadialGradient(colors: [Palette.copperLight, Palette.copper, Palette.copperDeep],
                                   center: UnitPoint(x: 0.35, y: 0.3),
                                   startRadius: 1, endRadius: size * 0.42)
                )
                .frame(width: size * 0.72, height: size * 0.72)
                .overlay(
                    Ellipse().fill(.white.opacity(0.3))
                        .frame(width: size * 0.22, height: size * 0.12)
                        .blur(radius: size * 0.03)
                        .offset(x: -size * 0.14, y: -size * 0.16)
                )

            // Concentric rings of scales wrapping the ball.
            ForEach(0..<3, id: \.self) { ring in
                let count = 8 + ring * 2
                let radius = size * (0.30 - CGFloat(ring) * 0.085)
                ForEach(0..<count, id: \.self) { i in
                    CoinScale(highlight: 0.05 + Double(ring) * 0.05)
                        .frame(width: size * 0.13, height: size * 0.16)
                        .rotationEffect(.radians(Double(i) / Double(count) * .pi * 2 + .pi/2))
                        .offset(x: cos(Double(i) / Double(count) * .pi * 2) * radius,
                                y: sin(Double(i) / Double(count) * .pi * 2) * radius)
                }
            }

            // A single eye peeking out over the top of the ball.
            ZStack {
                Circle().fill(.white).frame(width: size * 0.12, height: size * 0.12)
                Circle().fill(Palette.tealDeep).frame(width: size * 0.075, height: size * 0.075)
                Circle().fill(Palette.ink).frame(width: size * 0.045, height: size * 0.045)
                Circle().fill(.white).frame(width: size * 0.025, height: size * 0.025)
                    .offset(x: size * 0.016, y: -size * 0.014)
            }
            .scaleEffect(peek || reduceMotion ? 1 : 0.01, anchor: .bottom)
            .opacity(peek || reduceMotion ? 1 : 0)
            .offset(y: -size * 0.06)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Motion values

    private var bodyScale: CGFloat {
        guard !reduceMotion, appeared else { return 1 }
        switch mood {
        case .cheer: return hop ? 1.05 : 0.99
        case .idle, .wave: return breathe ? 1.02 : 1.0
        case .curl: return 1
        }
    }

    private var floatOffset: CGFloat {
        guard !reduceMotion, appeared else { return 0 }
        switch mood {
        case .cheer: return hop ? -size * 0.10 : 0
        case .idle, .wave: return breathe ? -size * 0.012 : 0
        case .curl: return 0
        }
    }

    private var tilt: Double {
        guard !reduceMotion, appeared else { return 0 }
        if mood == .cheer { return hop ? -3 : 3 }
        return 0
    }

    private var waveAngle: Double {
        guard !reduceMotion, appeared, mood == .wave else { return 12 }
        return wave ? 26 : -6
    }

    // MARK: - Motion lifecycle

    private func startMotion() {
        appeared = true
        guard !reduceMotion else {
            // Calm still pose: eyes open, arms per-mood, ball fully peeking.
            peek = true
            return
        }
        // Breathe / float.
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breathe = true
        }
        switch mood {
        case .cheer:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                hop = true
            }
        case .wave:
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                wave = true
            }
            scheduleBlink()
            scheduleLook()
        case .idle:
            scheduleBlink()
            scheduleLook()
        case .curl:
            // Roll in, settle, then peek out.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { curled = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { peek = true }
            }
        }
    }

    // Blink on a gentle random cadence.
    private func scheduleBlink() {
        blinkWork?.cancel()
        let delay = Double.random(in: 2.4...5.0)
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.09)) { eyesClosed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeInOut(duration: 0.11)) { eyesClosed = false }
                scheduleBlink()
            }
        }
        blinkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // Occasional glance left / right, then back to centre.
    private func scheduleLook() {
        lookWork?.cancel()
        let delay = Double.random(in: 3.0...6.0)
        let work = DispatchWorkItem {
            let dir: CGFloat = Bool.random() ? 1 : -1
            withAnimation(.easeInOut(duration: 0.5)) { lookX = dir }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeInOut(duration: 0.5)) { lookX = 0 }
                scheduleLook()
            }
        }
        lookWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func stopTimers() {
        blinkWork?.cancel(); blinkWork = nil
        lookWork?.cancel();  lookWork = nil
    }

    private var accessibilityText: String {
        switch mood {
        case .idle:  return "Penny the pangolin, smiling"
        case .wave:  return "Penny the pangolin, waving hello"
        case .cheer: return "Penny the pangolin, cheering with her arms up"
        case .curl:  return "Penny the pangolin, curled into a coin ball, peeking out"
        }
    }
}

// MARK: - Shapes

/// One shiny coin-scale: a rounded petal with a rim and a glossy top edge.
private struct CoinScale: View {
    /// 0 = base copper, higher = slightly brighter (for upper rows).
    var highlight: Double = 0

    var body: some View {
        ScaleShape()
            .fill(
                LinearGradient(
                    colors: [Palette.copperLight.lighter(highlight),
                             Palette.copper.lighter(highlight * 0.5),
                             Palette.copperDeep],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                ScaleShape()
                    .stroke(Palette.copperDeep.opacity(0.45), lineWidth: 1)
            )
            .overlay(
                // Glossy top sheen.
                ScaleShape()
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.45), .clear],
                                       startPoint: .top, endPoint: .center)
                    )
                    .padding(1.5)
            )
    }
}

/// A rounded teardrop / petal used for each coin-scale.
private struct ScaleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))            // pointed top
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.55),
                       control: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.55),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY + h * 0.12))
        _ = w
        p.closeSubpath()
        return p
    }
}

/// An upward-curving happy "^" eye.
private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.3))
        return p
    }
}

/// A gentle upward smile arc.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6))
        return p
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            PennyView(mood: .idle, size: 130)
            PennyView(mood: .wave, size: 130)
        }
        HStack(spacing: 24) {
            PennyView(mood: .cheer, size: 130)
            PennyView(mood: .curl, size: 130)
        }
    }
    .padding()
    .background(WarmBackground())
}
