#!/usr/bin/env bash
# CI-only NDK installation. Flutter 3.38.9 requires this side-by-side NDK.
# Android SDK archives can intermittently be truncated by the upstream CDN.
# Never change the NDK version, disable ZIP validation, or mask Gradle errors.
set -euo pipefail

version="28.2.13676358"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo "::error::ANDROID_SDK_ROOT or ANDROID_HOME must point to the Android SDK"
  exit 1
fi
sdkmanager=""
if command -v sdkmanager >/dev/null 2>&1; then
  sdkmanager="$(command -v sdkmanager)"
elif [[ -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]]; then
  sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
fi
if [[ -z "$sdkmanager" ]]; then
  echo "::error::Android SDK command-line tools (sdkmanager) are unavailable"
  exit 1
fi

ndk_dir="$sdk_root/ndk/$version"
is_complete() {
  [[ -f "$ndk_dir/source.properties" ]] &&
    [[ -x "$ndk_dir/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]] &&
    grep -Eq '^Pkg.Revision[[:space:]]*=[[:space:]]*28\.2\.13676358[[:space:]]*$' "$ndk_dir/source.properties"
}
if is_complete; then
  echo "Android NDK $version already installed and validated"
  exit 0
fi

for attempt in 1 2 3; do
  # This GitHub runner is disposable. Remove ONLY an incomplete target NDK,
  # not SDK platforms, licenses, other NDK versions, or the Gradle cache.
  if [[ -d "$ndk_dir" ]] && ! is_complete; then
    rm -rf -- "$ndk_dir"
  fi
  log="$(mktemp)"
  status=0
  timeout 300 "$sdkmanager" --sdk_root="$sdk_root" --install "ndk;$version" \
    2>&1 | tee "$log" || status=${PIPESTATUS[0]}

  if is_complete; then
    rm -f "$log"
    echo "Android NDK $version verified (source.properties and clang)"
    exit 0
  fi

  # Retry only transient CDN/download/ZIP failures. Real SDK configuration
  # errors must fail visibly instead of being treated as infrastructure.
  transient=false
  if [[ "$status" == 124 ]] ||
      grep -Eiq 'ZipFile|not a ZIP archive|unknown archive|corrupt|truncated|unexpected end|Connection reset|timed out|Read timed out|429|502|503|504|network is unreachable' "$log"; then
    transient=true
  fi
  rm -f "$log"
  if [[ "$transient" != true || "$attempt" == 3 ]]; then
    echo "::error::Android NDK $version installation failed (attempt $attempt, SDK status $status)"
    exit 1
  fi
  echo "::warning::Transient Android NDK archive/download failure; retry $((attempt + 1))/3"
  sleep $((attempt * 20))
done

echo "::error::NDK did not pass installation validation"
exit 1
