//
//  SortItScreenView.swift
//  "Sort it" (README section 3): drag pictures into groups, like Need and Want.
//
//  Two ways in, because six-year-olds and VoiceOver users hold a phone very
//  differently: drag a picture onto a basket, or tap the picture and then tap a
//  basket. Every drop gets the same right/wrong effects as any other answer —
//  a right one settles into the basket with a mint flash, a wrong one wobbles
//  back to the tray under the warm apricot glow, never a red X.
//

import SwiftUI

struct SortItScreenView: View {
    let screen: SortItScreen
    @ObservedObject var runner: LessonRunner

    /// Where each sorted picture ended up, by item id.
    @State private var placed: [String: String] = [:]
    /// The picture picked up by tapping, waiting for a basket.
    @State private var selected: String?
    /// The picture being dragged, and how far it has moved.
    @State private var dragging: String?
    @State private var dragOffset: CGSize = .zero
    /// The basket under the finger, for a highlight while dragging.
    @State private var hovered: String?
    /// The last picture that went in the wrong basket: it keeps the warm apricot
    /// tint while Penny's hint is up…
    @State private var rejected: String?
    /// …and wobbles once, briefly, on its way back to the tray.
    @State private var wobbling: String?
    /// Basket frames, so a drop knows which basket it landed in.
    @State private var basketFrames: [String: CGRect] = [:]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let boardSpace = "sortBoard"

    var body: some View {
        VStack(spacing: 16) {
            LessonPennyHeader(mood: runner.pennyMood, line: runner.pennyLine, pennySize: 88)
            LessonPrompt(text: runner.fill(screen.prompt))

            HStack(alignment: .top, spacing: 14) {
                ForEach(screen.groups) { group in
                    basket(group)
                }
            }
            .padding(.horizontal, 20)

            tray

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .coordinateSpace(name: boardSpace)
        .onPreferenceChange(BasketFrameKey.self) { basketFrames = $0 }
        .onChange(of: runner.outcome) { _, outcome in
            // Penny's hint has faded: the picture is simply back in the tray.
            if outcome == nil { rejected = nil }
        }
        .onAppear(perform: applyUITestFeedback)
    }

    // MARK: Baskets

    private func basket(_ group: SortItScreen.Group) -> some View {
        let items = screen.items.filter { placed[$0.id] == group.id }
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                if let icon = group.icon { FluentIcon(name: icon, size: 24) }
                Text(group.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(group.tint.color, in: Capsule())

            // What's already in the basket.
            HStack(spacing: 8) {
                ForEach(items) { item in
                    VStack(spacing: 2) {
                        FluentIcon(name: item.icon, size: 34)
                        Text(item.label).font(.caption2).foregroundStyle(Palette.textMuted)
                    }
                }
            }
            .frame(minHeight: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 10)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(hovered == group.id ? group.tint.color : Palette.borderField,
                        lineWidth: hovered == group.id ? Border.choice : Border.field)
        )
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: BasketFrameKey.self,
                                       value: [group.id: geometry.frame(in: .named(boardSpace))])
            }
        )
        // Tap-to-place: the second half of the tap route, and what VoiceOver uses.
        .onTapGesture { if let selected { place(itemID: selected, into: group.id) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.title) basket")
        .accessibilityHint(selected == nil ? "Pick a picture first." : "Puts the picture you picked in here.")
    }

    // MARK: Tray

    /// The pictures still waiting to be sorted.
    private var tray: some View {
        let remaining = screen.items.filter { placed[$0.id] == nil }
        return HStack(spacing: 12) {
            ForEach(remaining) { item in
                chip(item)
            }
        }
        .frame(minHeight: 96)
        .padding(.horizontal, 20)
        .animation(reduceMotion ? .easeInOut(duration: Motion.glow) : .spring(duration: Motion.step),
                   value: placed.count)
    }

    private func chip(_ item: SortItScreen.Item) -> some View {
        VStack(spacing: 6) {
            FluentIcon(name: item.icon, size: 46)
            Text(item.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textBody)
                // One line, shrunk if it must be: a hyphenated "Bal-loon" is
                // not something a six-year-old should have to read.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 72)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(chipFill(item), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .stroke(chipBorder(item), lineWidth: selected == item.id ? Border.choice : Border.field)
        )
        .rotationEffect(.degrees(wobbling == item.id && !reduceMotion ? Motion.wobbleDeg : 0))
        .animation(.easeInOut(duration: Motion.press).repeatCount(3, autoreverses: true), value: wobbling)
        .scaleEffect(dragging == item.id && !reduceMotion ? 1.06 : 1)
        .offset(dragging == item.id ? dragOffset : .zero)
        .zIndex(dragging == item.id ? 1 : 0)
        // Tap to pick up (and tap again to put down).
        .onTapGesture { selected = (selected == item.id) ? nil : item.id }
        // Or drag straight into a basket.
        .gesture(dragGesture(item))
        .accessibilityElement()
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(selected == item.id ? "Picked up" : "")
        .accessibilityHint("Pick this picture, then tap a basket.")
    }

    private func dragGesture(_ item: SortItScreen.Item) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(boardSpace))
            .onChanged { value in
                dragging = item.id
                selected = item.id
                dragOffset = value.translation
                hovered = basket(containing: value.location)
            }
            .onEnded { value in
                let target = basket(containing: value.location)
                dragging = nil
                dragOffset = .zero
                hovered = nil
                if let target {
                    place(itemID: item.id, into: target)
                }
            }
    }

    private func basket(containing point: CGPoint) -> String? {
        basketFrames.first { $0.value.contains(point) }?.key
    }

    // MARK: Sorting

    /// One drop. Right: the picture stays, mint flash, and when the last one is
    /// home Penny sums up the idea. Wrong: it wobbles back to the tray.
    private func place(itemID: String, into groupID: String) {
        guard !runner.canAdvance, let item = screen.items.first(where: { $0.id == itemID }) else { return }
        selected = nil
        if item.groupID == groupID {
            withAnimation(reduceMotion ? .easeInOut(duration: Motion.glow) : .spring(duration: Motion.step)) {
                placed[item.id] = groupID
            }
            let isLast = placed.count == screen.items.count
            runner.right(message: isLast ? screen.doneMessage : screen.rightMessage, advances: isLast)
        } else {
            rejected = item.id
            wobbling = item.id
            runner.wrong(message: screen.wrongMessage)
            // The wobble is a beat; the tint stays as long as Penny's hint does.
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if wobbling == item.id { wobbling = nil }
            }
        }
    }

    private func chipFill(_ item: SortItScreen.Item) -> Color {
        rejected == item.id ? Palette.stateRetryBg : Palette.surfaceCard
    }

    private func chipBorder(_ item: SortItScreen.Item) -> Color {
        if rejected == item.id { return Palette.stateRetryBorder }
        return selected == item.id ? Palette.borderFocus : Palette.borderField
    }

    /// Screenshots: sort everything but the last picture, then put that one in
    /// the right or the wrong basket.
    private func applyUITestFeedback() {
        guard let feedback = runner.takeUITestFeedback(), let last = screen.items.last else { return }
        for item in screen.items.dropLast() { placed[item.id] = item.groupID }
        switch feedback {
        case "right":
            place(itemID: last.id, into: last.groupID)
        case "wrong":
            if let wrongBasket = screen.groups.first(where: { $0.id != last.groupID })?.id {
                place(itemID: last.id, into: wrongBasket)
            }
        default: break
        }
    }
}

// MARK: - Basket geometry

/// Collects each basket's frame so a dragged picture knows where it was dropped.
private struct BasketFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
