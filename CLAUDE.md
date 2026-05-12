# RunJourney iOS — Claude Code Guide

## Project Overview
iOS running app built with SwiftUI and Xcode.

## Self-check (instead of CI)

GitHub Actions CI is currently **disabled** (Actions minutes exhausted). Until
it's restored there is no automated build feedback, so always run the local
sanity-check before committing Swift changes:

```bash
# Check only files changed vs HEAD (the common case)
scripts/sanity-check.sh

# Check every Swift file in the tree
scripts/sanity-check.sh --all
```

The script is purely textual (no Swift toolchain on this Linux env) and catches:
- Unbalanced `#if` / `#endif`
- Unbalanced `{}` / `()` (after stripping comments and string literals)
- Missing `import MapKit` / `import CoreLocation` when the file uses those APIs

It will not catch real semantic errors (typos in property names, wrong argument
labels, async-context mismatches, etc.) — those still slip through. When in
doubt:
1. Read the changed `.swift` files carefully
2. Compare to a known-working sibling file in the same feature
3. Ask the user to run `xcodebuild` locally and paste any output

The project uses Xcode 16's `PBXFileSystemSynchronizedRootGroup`, so newly-
added `.swift` files under `RunJourney/` are picked up automatically — no
need to register them in `project.pbxproj`.

## Build & Test (requires macOS / Xcode)

```bash
xcodebuild \
  -project RunJourney.xcodeproj \
  -scheme RunJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Repository Structure
- `RunJourney/` — main app source (SwiftUI)
- `RunJourneyTests/` — unit tests
- `RunJourneyUITests/` — UI tests
- `RunJourney.xcodeproj/` — Xcode project (synchronized root group)
- `scripts/sanity-check.sh` — textual pre-commit checks

## Branch Strategy
- `main` — protected
- Feature branches → PR → merge

## Restoring CI later
When GitHub Actions minutes become available again, the previous workflow
configuration is in git history (search `.github/workflows/ci.yml` before
the CI-removal commit). Restore it by checking out that file from history.
