#!/usr/bin/env bash
# SAFWA-008: safe, explicit local Android-emulator smoke test.
set -euo pipefail
umask 077
root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"

usage() {
  echo "Usage: bash scripts/android_emulator_smoke.sh inspect"
  echo "       bash scripts/android_emulator_smoke.sh run <emulator-serial>"
  echo "Start your emulator first; run requires an explicit emulator-XXXX ADB serial."
}
(( $# > 0 )) || { usage; exit 2; }

check_android() {
  local manifest="android/app/src/main/AndroidManifest.xml"
  local gradle="android/app/build.gradle.kts"
  local kotlin="android/app/src/main/kotlin/org/safwa/institute/safwa_quran/MainActivity.kt"
  [[ -f "$manifest" && -f "$gradle" && -f "$kotlin" ]] || {
    echo "Missing generated Android platform source; stop." >&2; exit 1;
  }
  grep -q 'android:name="flutterEmbedding"' "$manifest" || {
    echo "Android manifest lacks Flutter embedding metadata." >&2; exit 1;
  }
  grep -q 'android:value="2"' "$manifest" || {
    echo "Android manifest is not marked as embedding v2." >&2; exit 1;
  }
  grep -q 'io.flutter.embedding.android.FlutterActivity' "$kotlin" || {
    echo "MainActivity does not use the Flutter v2 embedding." >&2; exit 1;
  }
  package_id="$(sed -nE 's/^[[:space:]]*applicationId[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$gradle" | head -1)"
  [[ "$package_id" == "org.safwa.institute.safwa_quran" ]] || {
    echo "Unknown package identity '$package_id': manual audit required." >&2; exit 1;
  }
  echo "Android v2 configuration and provisional Safwa app identity verified."
}

apk="build/app/outputs/flutter-apk/app-debug.apk"
case "$1" in
  inspect)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    check_android
    git status --short android/ || true
    if [[ -s "$apk" ]]; then
      stat -c '%y %s bytes %n' "$apk"
      sha256sum "$apk"
    else
      echo "No debug APK. Build with: flutter build apk --debug"
    fi
    ;;
  run)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    serial="$2"
    [[ "$serial" =~ ^emulator-[0-9]+$ ]] || {
      echo "Only an explicit Android emulator serial is permitted." >&2; exit 2;
    }
    command -v adb >/dev/null || { echo "adb not on PATH" >&2; exit 1; }
    check_android
    [[ -s "$apk" ]] || { echo "Build a fresh debug APK first." >&2; exit 1; }
    [[ "$(adb -s "$serial" get-state 2>/dev/null || true)" == "device" ]] || {
      echo "ADB emulator not online: $serial" >&2; exit 1;
    }
    [[ "$(adb -s "$serial" shell getprop sys.boot_completed | tr -d '\r')" == "1" ]] || {
      echo "Android emulator has not completed boot." >&2; exit 1;
    }
    work=".staging/android-smoke/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$work"
    sha256sum "$apk" > "$work/apk-sha256.txt"
    printf 'branch=%s\nserial=%s\npackage=%s\n' \
      "$(git branch --show-current)" "$serial" "$package_id" > "$work/session.txt"
    echo "Installing debug Safwa APK on explicit emulator $serial"
    adb -s "$serial" install -r -t "$apk"
    echo "Launching Safwa app"
    adb -s "$serial" shell monkey -p "$package_id" \
      -c android.intent.category.LAUNCHER 1 > "$work/launch.txt" 2>&1
    sleep 3
    if ! adb -s "$serial" shell pidof "$package_id" > "$work/app-pid.txt"; then
      echo "App process not detected; inspect private launch log." >&2; exit 1;
    fi
    adb -s "$serial" exec-out screencap -p > "$work/launch.png"
    [[ -s "$work/launch.png" ]] || {
      echo "Screenshot capture failed; inspect emulator." >&2; exit 1;
    }
    echo "Install/launch smoke gate passed. Review screenshot: $work/launch.png"
    echo "Manual testing remains required. No release or religious approval."
    ;;
  *) usage; exit 2 ;;
esac
