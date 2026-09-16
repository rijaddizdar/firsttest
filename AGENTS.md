# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- **Stage:** early prototype. `README.md` is the product spec (guide animal Penny the Pangolin, the 13-level map, lesson flow, parent account model, privacy rules); update it when product decisions change. `App/` holds a source-only SwiftUI mock-up of the main screens (welcome → grown-up setup → level map → the one playable "Needs & Wants" lesson → code-locked parent dashboard); it is in-memory only, no SwiftData/backend/network yet. There is **no `.xcodeproj`** — see `docs/RUNNING.md` for opening it as a new iOS 17+ App target in Xcode.
- **Audience is children (6–11):** all kid-facing copy must follow the language and tone rules in `README.md` section 7.
- **Kids Category and COPPA constraints are hard rules:** no third-party analytics, advertising or tracking SDKs, no IDFA, and no child data beyond the table in `README.md` section 9. Only the parent signs in (Sign in with Apple is unavailable under 13).
- **Planned stack:** SwiftUI iOS app (see `README.md` section 8). The primary dev machine has only Xcode command line tools, not full Xcode, so the app cannot be built or run there yet. Verify Swift changes with parse/type-check against the macOS SDK (`xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos14 -typecheck App/*.swift`); guard iOS-only APIs with `#if canImport(UIKit)` / `#if os(iOS)`. `#Preview` macros need full Xcode and will not expand under Command Line Tools.
- **App name is intentionally absent** from all code/UI pending a trademark search; the `@main` type `MoneyPalsApp` is a placeholder only.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
