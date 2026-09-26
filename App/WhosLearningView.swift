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
        VStack(spacing: 24) {
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

            Text("Who's learning?")
                .font(.screenTitle)
                .foregroundStyle(Palette.textHeading)

            PennyView(mood: .wave, size: 120)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(app.kids) { kid in
                        Button {
                            app.selectedKidID = kid.id
                            app.route = .lessonMap
                        } label: {
                            VStack(spacing: 10) {
                                AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 96)
                                Text(kid.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Palette.textBody)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }

                    // Add-another-kid tile routes back through the grown-up gate.
                    // Dashed lock-grey ring (Penny Design System, shape-borders).
                    Button {
                        app.route = .parentGate
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().stroke(Palette.lockGrey, style: StrokeStyle(lineWidth: Border.choice, dash: [6]))
                                Image(systemName: "plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Palette.lockGrey)
                            }
                            .frame(width: 96, height: 96)
                            Text("Add kid").font(.title3).foregroundStyle(Palette.textSoft)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

#Preview {
    WhosLearningView().environmentObject(AppState())
}
