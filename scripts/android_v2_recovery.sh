#!/usr/bin/env bash
# Safwa Android v2 recovery. The project-specific Android folder is LOCAL
# and untracked; this script never edits Quran text or release flags.
set -euo pipefail
umask 077

root="$(cd "$(dirname "$0")/.." && pwd -P)"
base="$root/.staging/android-v2-recovery"
mkdir -p "$base"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/android_v2_recovery.sh inspect
  bash scripts/android_v2_recovery.sh prepare
  bash scripts/android_v2_recovery.sh apply /absolute/path/to/session-XXXXXXXX

'prepare' backs up the entire existing Android folder and generates a new
Flutter-v2 template in ignored .staging; it never replaces your Android project.
Inspect custom package IDs, signing configs, Firebase settings, native source,
permissions, manifest and Gradle differences BEFORE choosing 'apply'.
'apply' refuses any changes since preparation, backs up the old Android tree,
and swaps in the generated template with rollback on copy failure.
No source files in lib/, Quran assets, stash, or iOS directories are changed.
EOF
}

check_legacy() {
  local original="$root/android/app/src/main"
  local manifest="$original/AndroidManifest.xml"
  echo "Android directory: $root/android"
  if [[ ! -d "$root/android" ]]; then
    echo "Android platform directory is missing."
    return
  fi
  if [[ -f "$manifest" ]]; then
    echo "Manifest detected: $manifest"
    if grep -q 'flutterEmbedding' "$manifest"; then
      echo "Manifest declares flutterEmbedding (inspect its value)."
    else
      echo "Manifest lacks flutterEmbedding metadata; could select legacy v1."
    fi
  else
    echo "AndroidManifest.xml is missing from app/src/main."
  fi
  if [[ -d "$original" ]]; then
    echo "Legacy embedding references (if any):"
    grep -R -n -E --include='*.kt' --include='*.java' --include='*.xml' \
      'io\.flutter\.app\.|GeneratedPluginRegistrant\.registerWith|flutterEmbedding|SplashScreenUntilFirstFrame' \
      "$original" || true
  fi
  echo "A successful previous APK file is not evidence of this build's status."
}

verify_template() {
  local target="$1"
  local manifest="$target/android/app/src/main/AndroidManifest.xml"
  [[ -f "$manifest" ]] || {
    echo "ERROR: fresh manifest missing; refusing migration." >&2
    exit 1
  }
  if ! grep -q 'flutterEmbedding' "$manifest"; then
    echo "ERROR: fresh manifest does not declare v2; refusing migration." >&2
    exit 1
  fi
  if grep -R -q -E --include='*.kt' --include='*.java' --include='*.xml' \
    'io\.flutter\.app\.|GeneratedPluginRegistrant\.registerWith' \
    "$target/android/app/src/main"; then
    echo "ERROR: generated template still references v1; refusing migration." >&2
    exit 1
  fi
}

if (( $# == 0 )); then usage; exit 2; fi
mode="$1"
case "$mode" in
  inspect)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    check_legacy
    ;;
  prepare)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    [[ -d "$root/android" ]] || {
      echo "ERROR: no current Android platform directory to back up." >&2
      exit 1
    }
    command -v flutter >/dev/null || {
      echo "ERROR: Flutter is not installed/in PATH." >&2
      exit 1
    }
    work="$(mktemp -d "$base/session-XXXXXXXX")"
    cp -a "$root/android" "$work/original-android"
    echo "Original Android directory safely copied into: $work/original-android"
    echo "Generating fresh Android v2 scaffold in an isolated ignored directory..."
    flutter create --project-name safwa_quran --org org.safwa.institute \
      --platforms android "$work/template"
    verify_template "$work/template"
    echo
    echo "PREPARED: $work"
    echo "The old Android directory HAS NOT been replaced."
    echo "Review both trees and any signing, package-name, permission, Gradle,"
    echo "Firebase or custom MainActivity differences before applying."
    echo "To opt in: bash scripts/android_v2_recovery.sh apply '$work'"
    ;;
  apply)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    work="$(realpath -e "$2")"
    case "$work" in
      "$base"/session-*) ;;
      *) echo "ERROR: refuse path outside SAFWA recovery sessions." >&2; exit 2 ;;
    esac
    [[ -d "$root/android" && -d "$work/original-android" &&
       -d "$work/template/android" && ! -e "$work/android-before-apply" ]] || {
      echo "ERROR: missing Android snapshot, template or already applied." >&2
      exit 1
    }
    verify_template "$work/template"
    if ! diff -qr "$root/android" "$work/original-android" >/dev/null; then
      echo "ERROR: local Android tree has changed since preparation." >&2
      echo "Prepare a fresh snapshot; nothing was replaced." >&2
      exit 1
    fi
    oldapk="$root/build/app/outputs/flutter-apk/app-debug.apk"
    if [[ -f "$oldapk" ]]; then
      cp -p "$oldapk" "$work/old-app-debug.apk"
      echo "Older APK preserved for comparison; it is NOT the new build."
    fi
    mv "$root/android" "$work/android-before-apply"
    if ! cp -a "$work/template/android" "$root/android"; then
      echo "ERROR: migration copy failed. Attempting rollback..." >&2
      if [[ -e "$root/android" ]]; then
        mv "$root/android" "$work/incomplete-new-android" || true
      fi
      mv "$work/android-before-apply" "$root/android"
      exit 1
    fi
    echo "APPLIED: freshly generated Android v2 scaffold."
    echo "OLD ANDROID BACKUP: $work/android-before-apply"
    echo "Compare/reapply only reviewed native customizations from that backup."
    echo "Next: flutter doctor --android-licenses; flutter clean;"
    echo "      flutter pub get; flutter analyze; flutter test;"
    echo "      flutter build apk --debug"
    ;;
  *)
    usage
    exit 2
    ;;
esac
