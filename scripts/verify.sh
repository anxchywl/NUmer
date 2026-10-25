#!/usr/bin/env bash
# proves a change is acceptable, run before reporting and in ci
# not run here: device builds, emulator tests, deploys
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
dart run scripts/check_arb.dart
bash scripts/check_copy.sh
bash scripts/check_design.sh
flutter test --coverage
bash scripts/coverage_floor.sh coverage/lcov.info "$(cat scripts/coverage_floor.txt)"
(cd functions && npm ci && npm run build)
