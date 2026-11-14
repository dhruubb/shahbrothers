#!/usr/bin/env bash
# Generates the android/ and ios/ folders with `flutter create`, then adds
# the permissions, app name and icons Shah Brothers needs.
# Safe to re-run. Usage:  bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null 2>&1 || { echo "Flutter is not installed or not on PATH. See README."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required for the patch step."; exit 1; }

# Protect our own files from being touched by the template.
backup="$(mktemp -d)"
cp pubspec.yaml lib/main.dart README.md analysis_options.yaml .gitignore "$backup"/ 2>/dev/null || true

if [ ! -d android ] || [ ! -d ios ]; then
  echo "→ Creating Android and iOS projects…"
  flutter create . --project-name shah_brothers --org in.shahbrothers --platforms=android,ios
fi

cp "$backup"/pubspec.yaml pubspec.yaml
cp "$backup"/main.dart lib/main.dart
[ -f "$backup"/README.md ] && cp "$backup"/README.md README.md
[ -f "$backup"/analysis_options.yaml ] && cp "$backup"/analysis_options.yaml analysis_options.yaml
[ -f "$backup"/.gitignore ] && cp "$backup"/.gitignore .gitignore
# The template's counter-app test does not apply to this app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then rm test/widget_test.dart; fi

echo "→ Adding permissions, app name and icons…"
python3 tool/patch_platforms.py

echo "→ Fetching packages…"
flutter pub get

echo ""
echo "Done. Next:"
echo "  flutter run                                   # local demo mode"
echo "  flutter run --dart-define-from-file=env.json  # with Supabase"
