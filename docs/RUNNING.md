# Running the SwiftUI mock-up in Xcode

This repo contains an **interactive SwiftUI mock-up** of the app described in
`README.md`. It is source-only: there is **no `.xcodeproj`** yet, because the
machine it was authored on has only the Command Line Tools, not full Xcode, and
cannot create an iOS app target or run the Simulator.

The Swift source lives in [`App/`](../App).

## What it targets

- **iOS 17+**, SwiftUI. (README section 8 plans iOS 18 for live RealityKit Penny;
  this mock-up uses only plain SwiftUI and runs on iOS 17.)
- iPhone and iPad.
- On-device only: no backend, no network, no third-party packages. All data is
  in memory and resets each launch.

## Open it in Xcode

1. In Xcode: **File → New → Project… → iOS → App**.
   - Interface: **SwiftUI**, Language: **Swift**.
   - Set the minimum deployment target to **iOS 17.0**.
   - Give it any temporary name — the app name is intentionally not set anywhere
     in the code (held pending a trademark search); the `@main` type is called
     `MoneyPalsApp`, a placeholder only.
2. Delete the auto-generated `ContentView.swift` and the `...App.swift` file the
   template created (this project has its own `@main` in `App/MoneyPalsApp.swift`).
3. **Drag every file from `App/` into the project** (check "Copy items if
   needed" and add to the app target). That's:
   - `MoneyPalsApp.swift` — `@main` entry point + root router
   - `AppState.swift` — navigation + in-memory data
   - `Models.swift` — model types + the 13-level sample data
   - `Theme.swift`, `SharedUI.swift`, `PennyView.swift` — palette + reusable UI
   - `WelcomeView.swift`, `SetupView.swift`, `WhosLearningView.swift`,
     `LessonMapView.swift`, `LessonPlayerView.swift`, `ParentDashboardView.swift`
     — the screens
4. Build and run on an iPhone or iPad simulator (or device).

No assets catalog entries are required — Penny and every icon are drawn from
SwiftUI shapes and SF Symbols.

## What to try (the full flow)

- **Welcome** → *A grown-up sets this up* → **press-and-hold** 3s gate →
  **create a 6-digit parent code** → **add a kid** (name + boy/girl + colour).
- Or tap **See a demo (skip setup)** to jump to the seeded kid, "Mia".
- **Who's learning?** → tap an avatar → the **13-level map** (locked / current /
  completed, stars, coins, a coin-based streak).
- Tap **Needs & Wants** (Level 2, the one playable lesson): Hello → Learn →
  tap-to-choose questions with the **soft-green right** / **warm-apricot wrong**
  full-screen glow, Penny cheering or curling up, then the **Yay!** screen with
  stars, coins and streak.
- From "Who's learning?", tap **Grown-ups** → enter the code (demo: `1234`) to
  open the **parent dashboard**. Enter it wrong several times to see the short
  **lockout**.
- Turn on **Settings → Accessibility → Reduce Motion** to confirm the fade-only
  behaviour (nothing bounces or wobbles).

## Verified without Xcode

Every file was parse-checked and the whole set type-checked against the macOS
SDK:

```sh
SDK="$(xcrun --show-sdk-path)"
xcrun swiftc -sdk "$SDK" -target arm64-apple-macos14 -parse App/<file>.swift
```

All files pass. iOS-only APIs (`UIKit` haptics, `.keyboardType`) are guarded with
`#if canImport(UIKit)` / `#if os(iOS)`, so the code even type-checks on macOS.
`#Preview` macros require the full Xcode toolchain and cannot be expanded by the
Command Line Tools — that is the only thing not verifiable here.

## Still needs a first build in Xcode

This has **not** been built or run — there is no Xcode on the authoring machine.
A first Xcode build should confirm: `#Preview` expansion, iOS layout on real
device sizes, haptics, and the SF Symbol names render on the chosen iOS version
(a few symbols are iOS 17+; swap any that are missing on your deployment target).
