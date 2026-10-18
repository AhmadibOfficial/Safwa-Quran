# Verify a separate official Tanzil export (offline, no auto-approval)

The Tanzil download page is https://tanzil.net/download/ . Its published
release is Uthmani version 1.1 (February 2021), and the form provides
options for pause marks, sajdah, rub-el-hizb, tatweel and sequential tanween.
See https://tanzil.net/docs/version_1.1_updates and
https://tanzil.net/docs/Text_License for authoritative text updates and terms.

1. Using your browser, download Uthmani v1.1 directly from Tanzil.
   Select plain text (prefer surah|ayah|text / txt-2), and explicitly record
   the state of all five options. Keep the downloaded file byte-for-byte.
   Do not edit, normalize or automatically promote it to app assets.
2. Store the downloaded file privately outside the repo. For example:
   ~/Downloads/tanzil-official-uthmani.txt
3. In the Safwa-Quran checkout, run:

    python3 scripts/verify_official_tanzil.py --official ~/Downloads/tanzil-official-uthmani.txt --marks on --sajdah on --rub on --tatweel on --stanween off

These option values are an EXAMPLE: use the options ACTUALLY chosen in
the official web form. Unknown options must be marked unknown, not guessed.

The script accepts numbered and unnumbered 6,236-line text; verifies that
the source includes recognizable Tanzil copyright and license notices;
checks the pinned internal Quran source and verse alignment; records the
download's SHA-256; compares exact Arabic strings, diagnostic tatweel-only
differences and all remaining references. Results are written to
.staging/official_tanzil_comparison.json (ignored by Git).

IMPORTANT: this process is a comparison and reproducibility aid. A
self-provided file and checkbox labels cannot authenticate download provenance,
scholarly correctness or reviewer identity. Keep independent qualified
human review, official provenance evidence, license attribution, font and
device testing, and separate public release approval as mandatory gates.
Neither the comparison tool nor its tests change the Quran corpus,
reader activation flags, or public release policy.
