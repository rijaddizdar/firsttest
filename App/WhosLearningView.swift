//
//  WhosLearningView.swift
//  "Who's learning?" — each child taps their own avatar (README section 6).
//  Also holds the small, out-of-the-way entry to the grown-up area.
//

import SwiftUI

struct WhosLearningView: View {
    @EnvironmentObject private var app: AppState

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 20)]

    var body: some View {
        VStack(spacing: Metric.lg) {
            HStack {
                Spacer()
                // Parent-area entry. Small and top-corner so a child doesn't
                // wander in; it still leads to the code gate.
                Button {
                    Haptics.selection()
                    app.route = .parentGate
                } label: {
                    Label("Grown-ups", systemImage: "gearshape.fill")
                        .font(.kidCaption)
                        .foregroundStyle(Palette.teal)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.white).softShadow())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metric.lg)
            .padding(.top, Metric.md)

            PennyView(mood: .wave, size: 128)

            Text("Who's learning?")
                .font(.kidTitle)
                .foregroundStyle(Palette.teal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: Metric.lg) {
                    ForEach(app.kids) { kid in
                        Button {
                            Haptics.selection()
                            app.selectedKidID = kid.id
                            app.route = .lessonMap
                        } label: {
                            VStack(spacing: Metric.sm) {
                                AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 100)
                                Text(kid.name)
                                    .font(.kidHeadline)
                                    .foregroundStyle(Palette.ink)
                            }
                            .padding(.vertical, Metric.md)
                            .frame(maxWidth: .infinity)
                            .cardSurface()
                        }
                        .buttonStyle(PressableCard())
                    }

                    // Add-another-kid tile routes back through the grown-up gate.
                    Button {
                        app.route = .parentGate
                    } label: {
                        VStack(spacing: Metric.sm) {
                            ZStack {
                                Circle().stroke(Palette.lockGrey, style: StrokeStyle(lineWidth: 3, dash: [7]))
                                Image(systemName: "plus")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(Palette.lockGrey)
                            }
                            .frame(width: 100, height: 100)
                            Text("Add kid").font(.kidHeadline).foregroundStyle(Palette.ink.opacity(0.55))
                        }
                        .padding(.vertical, Metric.md)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableCard())
                }
                .padding(.horizontal, Metric.pagePadding)
                .padding(.top, Metric.xs)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

/// A gentle spring press for whole-card tappable tiles.
struct PressableCard: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.95 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

#Preview {
    WhosLearningView().environmentObject(AppState())
}
