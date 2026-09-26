//
//  WhosLearningView.swift
//  "Who's learning?" — each child taps their own avatar (README section 6).
//  Also holds the small, out-of-the-way entry to the grown-up area.
//

import SwiftUI

struct WhosLearningView: View {
    @EnvironmentObject private var app: AppState

    // `alignment: .top` keeps every avatar circle on the same line when one
    // name wraps to two lines and its neighbour does not.
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 20, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Parent-area entry. Small and top-corner so a child doesn't
                // wander in; it still leads to the code gate.
                Button {
                    app.route = .parentGate
                } label: {
                    HStack(spacing: 6) {
                        FluentIcon(name: "gear", size: 20)
                        Text("Grown-ups")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.teal)
                    }
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // The title, Penny and the avatars scroll as ONE block. Scrolling
            // only the grid left it squashed into whatever height the fixed
            // header had spared, which cut the bottom row of avatars off.
            ScrollView {
                VStack(spacing: 24) {
                    Text("Who's learning?")
                        .font(.screenTitle)
                        .foregroundStyle(Palette.textHeading)
                        .multilineTextAlignment(.center)

                    PennyView(mood: .wave, size: 120)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(app.kids) { kid in
                            Button {
                                app.selectedKidID = kid.id
                                app.route = .lessonMap
                            } label: {
                                AvatarTile(name: kid.name, tint: Palette.textBody) {
                                    AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 96)
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }

                        // Add-another-kid tile routes back through the grown-up gate.
                        // Dashed lock-grey ring (Penny Design System, shape-borders).
                        Button {
                            app.route = .parentGate
                        } label: {
                            AvatarTile(name: "Add kid", tint: Palette.textSoft, bold: false) {
                                ZStack {
                                    Circle().stroke(Palette.lockGrey, style: StrokeStyle(lineWidth: Border.choice, dash: [6]))
                                    Image(systemName: "plus")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Palette.lockGrey)
                                }
                                .frame(width: 96, height: 96)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                // Keeps the last row of avatars clear of the bottom edge
                // instead of ending flush against it.
                .padding(.bottom, 32)
            }
            // A short list still sits where it always did — no idle bouncing.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

/// One avatar tile: the round badge with the name underneath. The name keeps
/// its own line height and may take two lines, shrinking to fit only if two
/// lines still aren't enough — so a long name is always shown in full rather
/// than truncated, at every Dynamic Type size.
private struct AvatarTile<Badge: View>: View {
    let name: String
    let tint: Color
    var bold = true
    @ViewBuilder let badge: Badge

    var body: some View {
        VStack(spacing: 10) {
            badge
            Text(name)
                .font(bold ? .title3.weight(.bold) : .title3)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WhosLearningView().environmentObject(AppState())
}
