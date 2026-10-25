#!/usr/bin/env bash
# SAFWA-009: app source and Quran policy gate without emulator or Gradle.
set -euo pipefail

cd "$(dirname "$0")/.."

if (( $# > 1 )); then
  echo "Usage: bash scripts/verify_source_only.sh [--offline]" >&2
  exit 2
fi
if (( $# == 1 )) && [[ "$1" != "--offline" ]]; then
  echo "Usage: bash scripts/verify_source_only.sh [--offline]" >&2
  exit 2
fi

command -v python3 >/dev/null || {
  echo "Python 3 is required for Quran integrity tests." >&2
  exit 1
}
command -v flutter >/dev/null || {
  echo "Flutter SDK is required. No emulator or Gradle will be used." >&2
  exit 1
}

echo "===== Offline Quran integrity tests ====="
python3 -m unittest discover -s scripts/tests -v
python3 scripts/quran_pipeline.py check

echo '===== Offline recitation audio rights / asset gate ====='
python3 scripts/check_offline_audio.py

if python3 scripts/quran_pipeline.py release; then
  echo "ERROR: Public release unexpectedly allowed." >&2
  exit 1
fi

echo "===== Flutter dependencies (no Android/Gradle build) ====="
if [[ "${1:-}" == "--offline" ]]; then
  flutter pub get --offline
else
  flutter pub get
fi

echo "===== Dart static analysis ====="
flutter analyze

echo "===== Flutter unit/widget tests ====="
flutter test

echo "===== Check local patches ====="
git diff --check

echo "PASS: Safwa source-only gate. No emulator, Gradle, APK or release."
