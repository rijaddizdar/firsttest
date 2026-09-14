# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- **Stage:** concept only. There is no app code, Xcode project or backend yet. `README.md` is the product spec: guide animal (Penny the Pangolin), the 13-level map, lesson flow, parent account model and privacy rules. Update it when product decisions change.
- **Audience is children (6–11):** all kid-facing copy must follow the language and tone rules in `README.md` section 7.
- **Kids Category and COPPA constraints are hard rules:** no third-party analytics, advertising or tracking SDKs, no IDFA, and no child data beyond the table in `README.md` section 9. Only the parent signs in (Sign in with Apple is unavailable under 13).
- **Planned stack:** SwiftUI iOS app (see `README.md` section 8). The primary dev machine has only Xcode command line tools, not full Xcode, so the app cannot be built or run there yet.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
