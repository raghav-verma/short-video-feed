#!/usr/bin/env bash
# The same checks CI runs, locally. Golden tests included (run on macOS).
set -euo pipefail
cd "$(dirname "$0")/.."

dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart format --set-exit-if-changed $(git ls-files -co --exclude-standard '*.dart' | grep -v '\.g\.dart$')
flutter analyze
flutter test
