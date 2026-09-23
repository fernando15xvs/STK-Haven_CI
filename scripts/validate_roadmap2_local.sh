#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASELINE_WEB_SNAPSHOT=""
cleanup() {
  if [[ -n "$BASELINE_WEB_SNAPSHOT" && -d "$BASELINE_WEB_SNAPSHOT" ]]; then
    rm -rf "$BASELINE_WEB_SNAPSHOT"
  fi
}
trap cleanup EXIT

echo "== STK Haven Roadmap 2.0 final local validation =="
echo "Repository: $ROOT_DIR"
echo "Commit: $(git rev-parse HEAD)"
echo

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree must be clean before validating the release candidate." >&2
  git status --short >&2
  exit 1
fi

# Full baseline matrix: pub get, analyze, all core/mobile tests, Android
# debug/release, web dart2js release, and iOS release on macOS.
./scripts/validate_local.sh

echo
echo "[R2-1/6] Web widget/responsive tests"
(
  cd apps/app_web
  flutter pub get
  flutter test
)

echo
echo "[R2-2/6] Android profile + distribution artifacts (Android entrypoint only)"
(
  cd apps/app_mobile
  flutter build apk --profile --target lib/main_android.dart
  flutter build appbundle --release --target lib/main_android.dart
  flutter build apk --release --split-per-abi --target lib/main_android.dart
)

echo
echo "[R2-3/6] Preserve the exact validated dart2js Pages artifact"
BASELINE_WEB_SNAPSHOT="$(mktemp -d "${TMPDIR:-/tmp}/stk-haven-web-dart2js.XXXXXX")"
if [[ ! -d apps/app_web/build/web ]]; then
  echo "ERROR: baseline web artifact is missing after validate_local.sh." >&2
  exit 1
fi
cp -a apps/app_web/build/web/. "$BASELINE_WEB_SNAPSHOT/"

echo "Baseline dart2js artifact:"
du -sh "$BASELINE_WEB_SNAPSHOT" 2>/dev/null || true

echo
echo "[R2-4/6] Build optional WebAssembly comparison artifact"
(
  cd apps/app_web
  if [[ "${MSYSTEM:-}" != "" ]]; then
    MSYS_NO_PATHCONV=1 flutter build web --release --wasm --base-href /STK-Haven/
  else
    flutter build web --release --wasm --base-href /STK-Haven/
  fi
  rm -rf build/web-wasm-roadmap2
  cp -a build/web build/web-wasm-roadmap2
  echo "WASM comparison artifact:"
  du -sh build/web-wasm-roadmap2 2>/dev/null || true
)

echo
echo "[R2-5/6] Restore exact validated dart2js artifact for Pages"
rm -rf apps/app_web/build/web
mkdir -p apps/app_web/build/web
cp -a "$BASELINE_WEB_SNAPSHOT/." apps/app_web/build/web/

for required in \
  apps/app_web/build/web/index.html \
  apps/app_web/build/web/flutter_bootstrap.js \
  apps/app_web/build/web/sw.js; do
  if [[ ! -f "$required" ]]; then
    echo "ERROR: restored validated Pages artifact is missing $required" >&2
    exit 1
  fi
done

echo
echo "[R2-6/6] iOS profile build when running on macOS (iOS entrypoint only)"
if [[ "$(uname -s)" == "Darwin" ]]; then
  (
    cd apps/app_mobile
    flutter build ios --profile --no-codesign --target lib/main_ios.dart
  )
else
  echo "SKIP: iOS profile build and physical-device profiling require macOS."
fi

echo
echo "== Roadmap 2.0 artifact summary =="
ls -lh apps/app_mobile/build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
ls -lh apps/app_mobile/build/app/outputs/bundle/release/*.aab 2>/dev/null || true

echo
echo "SUCCESS: Roadmap 2.0 local build/test matrix available on this machine passed."
echo "IMPORTANT: apps/app_web/build/web is the exact validated dart2js Pages artifact."
echo "WASM comparison is retained separately at apps/app_web/build/web-wasm-roadmap2."
echo "Physical Android/iOS profile checks, golden approval and browser/PWA smoke checks remain manual audit items."
