#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m unittest discover -s scripts/tests -v
python3 scripts/quran_pipeline.py check
python3 scripts/compare_uthmani_editions.py \
  --primary sources/review_only/tanzil_uthmani_1.1_verbatim.txt \
  --secondary sources/review_only/secondary_tanzil_uthmani_verbatim.txt \
  --catalog assets/data/chapters.tsv \
  --report .staging/corpus_comparison.json
if python3 scripts/quran_pipeline.py release; then
  echo 'ERROR: release must remain disabled' >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo 'NOT VERIFIED: Flutter missing. Do not mark this gate green.' >&2
  exit 2
fi
flutter create --project-name safwa_quran --org org.safwa.institute --platforms android,ios .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
echo 'PASS: local development checks only. NOT production release.'
