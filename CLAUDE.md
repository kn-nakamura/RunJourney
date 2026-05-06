# RunJourney iOS — Claude Code Guide

## Project Overview
iOS running app built with SwiftUI and Xcode. CI runs on GitHub Actions (`macos-latest`) using `xcodebuild`.

## CI / GitHub Actions

### ⚠️ CI Logs are NOT directly accessible from this environment
`gh` CLI is installed but **requires a GitHub Personal Access Token** (`GH_TOKEN`) to access workflow logs.

**When CI fails, follow this exact procedure — do NOT loop:**

1. **Check what changed** — review the diff/commits on the current branch
2. **Read the CI workflow** — `.github/workflows/ci.yml` shows what steps run
3. **Diagnose from code** — look for Swift compilation issues, missing symbols, type mismatches in the changed files
4. **Ask the user** — if the cause isn't clear from code review alone, ask the user to paste the failed step's log from GitHub (Actions tab → failed run → expand the failing step)

**Do NOT:**
- Retry `gh run list` or GitHub API calls more than once when they fail with auth errors
- Loop through multiple approaches to access logs when the token is missing
- Pretend you found the log when you haven't

### Accessing CI Logs (when GH_TOKEN is configured)
```bash
# List recent workflow runs for the current branch
gh run list --repo kn-nakamura/run-journey-ios --branch $(git branch --show-current) --limit 5

# View failed logs for a specific run ID
gh run view --repo kn-nakamura/run-journey-ios --log-failed <RUN_ID>

# Shortcut: most recent failed run on current branch
gh run list --repo kn-nakamura/run-journey-ios --branch $(git branch --show-current) --status failure --limit 1 --json databaseId --jq '.[0].databaseId' | xargs -I{} gh run view --repo kn-nakamura/run-journey-ios --log-failed {}
```

### Setting up GH_TOKEN (one-time setup)
If the user provides a GitHub Personal Access Token:
```bash
echo "<TOKEN>" | gh auth login --with-token
# OR set the env var:
export GH_TOKEN=<TOKEN>
```

## Build & Test (local simulation)
```bash
# The CI build command (for reference — requires macOS with Xcode)
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
- `RunJourney.xcodeproj/` — Xcode project
- `.github/workflows/ci.yml` — CI pipeline

## Branch Strategy
- `main` — protected, requires CI to pass
- Feature branches → PR → CI → merge

## Common CI Failure Causes
1. **Build error**: Swift type error, missing import, undefined symbol → check changed `.swift` files
2. **Xcode version mismatch**: uses `macos-latest`, Xcode version can change → check `xcodebuild -version` output in CI log
3. **Test failure**: assertion failure in `RunJourneyTests/` → check test files and the logic they cover
