#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== STK Haven local validation =="
echo "Repository: $ROOT_DIR"
echo

command -v flutter >/dev/null 2>&1 || {
  echo "ERROR: Flutter is not available in PATH." >&2
  exit 1
}

flutter --version

echo
echo "[1/7] Resolve workspace dependencies"
flutter pub get

echo
echo "[2/7] Analyze workspace"
flutter analyze --no-fatal-infos

echo
echo "[3/7] Test shared core"
(
  cd packages/core
  flutter test
)

echo
echo "[4/7] Test mobile app"
(
  cd apps/app_mobile
  flutter pub get
  flutter test
)

echo
echo "[5/7] Build Android debug + release (Android entrypoint only)"
(
  cd apps/app_mobile
  flutter build apk --debug --target lib/main_android.dart
  flutter build apk --release --target lib/main_android.dart
)

echo
echo "[6/7] Build web release for GitHub Pages"
(
  cd apps/app_web
  flutter pub get
  if [[ "${MSYSTEM:-}" != "" ]]; then
    echo "Detected Git Bash/MSYS; disabling path conversion for --base-href."
    MSYS_NO_PATHCONV=1 flutter build web --release --base-href /STK-Haven/
  else
    flutter build web --release --base-href /STK-Haven/
  fi
)

echo
echo "[7/7] Build iOS release without signing (iOS entrypoint only)"
if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v pod >/dev/null 2>&1; then
    (
      cd apps/app_mobile/ios
      pod install
    )
  else
    echo "ERROR: CocoaPods is required for the iOS validation step." >&2
    exit 1
  fi
  (
    cd apps/app_mobile
    flutter build ios --release --no-codesign --target lib/main_ios.dart
  )
else
  echo "SKIP: iOS build requires macOS. Run this script on a Mac to reproduce the full CI matrix."
fi

echo
echo "SUCCESS: all validation steps available on this machine passed."
