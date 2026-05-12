#!/usr/bin/env bash
# Textual sanity checks for Swift sources in this iOS project.
#
# GitHub Actions CI is disabled (Actions minutes exhausted). Until it's restored,
# this script gives us a cheap pre-commit smoke test that catches the kinds of
# mistakes a `xcodebuild` failure would normally surface — without needing a
# macOS host or Xcode.
#
# It is purely textual: no Swift parser, no semantic analysis. It catches:
#   1. Unbalanced `#if` / `#endif` blocks
#   2. Unbalanced `{` / `}` and `(` / `)` (a coarse but useful signal)
#   3. Missing `import MapKit` / `import CoreLocation` for files that reference
#      `MKMapSnapshotter`, `CLLocationCoordinate2D`, etc. Comments and string
#      literals are stripped before scanning, so doc-comments do not trigger.
#
# The project uses Xcode 16 `PBXFileSystemSynchronizedRootGroup`, which auto-
# includes every file under `RunJourney/`. No `project.pbxproj` registration
# check is needed — new files are picked up by Xcode automatically.
#
# Usage:
#   scripts/sanity-check.sh                # Check changed Swift files vs HEAD
#   scripts/sanity-check.sh --all          # Check every .swift file in-tree
#   scripts/sanity-check.sh path/a.swift … # Check explicit files
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -u

cd "$(dirname "$0")/.."

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }

# ---- file selection ----

mode="${1:-}"
files=()

case "$mode" in
  "")
    while IFS= read -r line; do
      [ -n "$line" ] && files+=("$line")
    done < <(
      { git diff --name-only --diff-filter=AMR HEAD 2>/dev/null;
        git diff --name-only --diff-filter=AMR --staged 2>/dev/null;
        git ls-files --others --exclude-standard 2>/dev/null; } \
      | grep -E '\.swift$' | sort -u
    )
    ;;
  --all)
    while IFS= read -r line; do
      files+=("$line")
    done < <(find RunJourney RunJourneyTests RunJourneyUITests -name '*.swift' 2>/dev/null | sort)
    ;;
  *)
    files=("$@")
    ;;
esac

if [ ${#files[@]} -eq 0 ]; then
  green "✓ No Swift files to check."
  exit 0
fi

# Strip Swift comments and string literals to avoid false positives on symbol
# scanning. Imperfect (e.g. multi-line `"""..."""` and raw `#"..."#` strings
# aren't fully handled), but good enough for symbol detection.
#
# Order matters: strings first, otherwise `"http://"` is mis-parsed as a
# line-comment starting at `//` inside the URL.
strip_noise() {
  perl -0pe '
    s{"(?:\\.|[^"\\\n])*"}{""}g; # "string literals"
    s{/\*.*?\*/}{}gs;            # /* block comments */
    s{//[^\n]*}{}g;              # // line comments
  ' "$1"
}

printf "Checking %d Swift file(s)...\n" "${#files[@]}"
errors=0

for f in "${files[@]}"; do
  [ -f "$f" ] || continue

  # ----- 1. #if / #endif balance (works on raw file; pragmas don't appear in strings) -----
  ifs=$(grep -cE '^[[:space:]]*#if([[:space:]]|$)' "$f" || true)
  endifs=$(grep -cE '^[[:space:]]*#endif([[:space:]]|$)' "$f" || true)
  if [ "$ifs" != "$endifs" ]; then
    red "  ✗ $f: #if=$ifs / #endif=$endifs (unbalanced)"
    errors=$((errors + 1))
  fi

  # Cleaned source for the remaining checks.
  cleaned=$(strip_noise "$f")

  # ----- 2. brace / paren balance on cleaned source -----
  opens=$(printf '%s' "$cleaned" | tr -cd '{' | wc -c | tr -d ' ')
  closes=$(printf '%s' "$cleaned" | tr -cd '}' | wc -c | tr -d ' ')
  if [ "$opens" != "$closes" ]; then
    red "  ✗ $f: {=$opens / }=$closes (unbalanced)"
    errors=$((errors + 1))
  fi

  pop=$(printf '%s' "$cleaned" | tr -cd '(' | wc -c | tr -d ' ')
  pcl=$(printf '%s' "$cleaned" | tr -cd ')' | wc -c | tr -d ' ')
  if [ "$pop" != "$pcl" ]; then
    red "  ✗ $f: (=$pop / )=$pcl (unbalanced)"
    errors=$((errors + 1))
  fi

  # ----- 3. import vs symbol usage (on cleaned source) -----
  has_uikit_import=0
  has_mapkit_import=0
  has_coreloc_import=0
  printf '%s' "$cleaned" | grep -qE '^import UIKit([[:space:]]|$)'        && has_uikit_import=1   || true
  printf '%s' "$cleaned" | grep -qE '^import MapKit([[:space:]]|$)'       && has_mapkit_import=1  || true
  printf '%s' "$cleaned" | grep -qE '^import CoreLocation([[:space:]]|$)' && has_coreloc_import=1 || true

  uses_mapkit=0
  uses_coreloc=0
  printf '%s' "$cleaned" \
    | grep -qE '\b(MKMapSnapshotter|MKCoordinateRegion|MKCoordinateSpan|MKMapRect|MKMapView|MKMapItem|MKAnnotation|MKPolyline|MKMapType)\b' \
    && uses_mapkit=1 || true
  printf '%s' "$cleaned" \
    | grep -qE '\b(CLLocationCoordinate2D|CLLocation|CLLocationManager)\b' \
    && uses_coreloc=1 || true

  if [ "$uses_mapkit" = 1 ] && [ "$has_mapkit_import" = 0 ]; then
    red "  ✗ $f: uses MapKit symbols but does not 'import MapKit'"
    errors=$((errors + 1))
  fi
  # CoreLocation is re-exported by MapKit, so only flag if neither is imported.
  if [ "$uses_coreloc" = 1 ] && [ "$has_coreloc_import" = 0 ] && [ "$has_mapkit_import" = 0 ]; then
    red "  ✗ $f: uses CoreLocation symbols but imports neither CoreLocation nor MapKit"
    errors=$((errors + 1))
  fi
done

echo
if [ "$errors" -gt 0 ]; then
  red "FAILED with $errors error(s)."
  exit 1
fi
green "✓ All checks passed (${#files[@]} file(s))."
exit 0
