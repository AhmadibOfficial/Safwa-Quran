# Safwa Quran — صفوة القرآن
Official Safwa Institute Flutter project. Project source is private.

SAFWA-003: 114-surah offline directory, search, reading interface, persisted Surah and ayah bookmarks, adjustable Arabic font, continue-reading progress, fail-closed verified-text gate, and automated CI checks. A **complete 6,236-ayah original-source copy and verbatim-matched JSON candidate now exist in `sources/review_only/`**. They are NOT bundled in the application or independently approved.

## Developer setup
1. Install Flutter stable.
2. Run `flutter create --project-name safwa_quran --org org.safwa.institute --platforms android,ios .` (identifier provisional).
3. Run `flutter pub get && flutter analyze && flutter test`.
4. Run `python3 scripts/quran_pipeline.py check`.
5. On a trusted internet-connected machine, generate a quarantined Tanzil candidate via `python3 scripts/quran_pipeline.py acquire --out .staging/tanzil`.

## Release policy
Arabic Quran verses must never be invented. Validate source SHA, counts and exact characters against trusted independent data and secure two separate reviews before approving `assets/data/quran_verified.json`. Never activate by merely changing flags. Release remains disabled pending security, copyright, religious, and device checks.
