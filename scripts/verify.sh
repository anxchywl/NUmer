#!/usr/bin/env bash
# proves a change is acceptable, run before reporting and in ci
# not run here: device builds, emulator tests (run: cd functions && npm run test:emulator), deploys
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
(cd functions && npm ci && npm run build && npm test)
if command -v shellcheck >/dev/null; then
  find infra -name '*.sh' -exec shellcheck {} +
else
  echo "shellcheck is not installed, skipping infra scripts"
fi
