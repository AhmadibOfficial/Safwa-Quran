# Safwa Quran — صفوة القرآن
Independent offline-first Quran project initiated by Ahmad Ibrahim. Safwa Studios collaboration and use of the Safwa Institute name/logo are under discussion and not formally authorized. This branch is source-only; public release remains blocked.

SAFWA-003: 114-surah offline directory, search, reading interface, persisted Surah and ayah bookmarks, adjustable Arabic font, continue-reading progress, fail-closed verified-text gate, and automated CI checks. A **complete 6,236-ayah original-source copy and verbatim-matched JSON candidate now exist in `sources/review_only/`**. They are NOT bundled in the application or independently approved.

## Developer setup
1. Install Flutter stable.
2. Run `flutter create --project-name safwa_quran --org org.safwa.institute --platforms android,ios .` (identifier provisional).
3. Run `flutter pub get && flutter analyze && flutter test`.
4. Run `python3 scripts/quran_pipeline.py check`.
5. On a trusted internet-connected machine, generate a quarantined Tanzil candidate via `python3 scripts/quran_pipeline.py acquire --out .staging/tanzil`.

## AI-assisted development and confidentiality

This branch includes draft **SAFWA-017** security safeguards for Claude Code, Codex and other AI-assisted engineering:

- [AI confidentiality and secure development policy](docs/AI-CONFIDENTIALITY-AND-SECURE-DEVELOPMENT.md)
- [Agent workspace policy](AGENTS.md)
- [Read-only Gitleaks and Semgrep CI](.github/workflows/ai-security.yml)
- [Direct dependency review baseline](config/dependency_review_baseline.json)

The safeguards do **not** authorize any release or guarantee hosted AI providers' retention/training policies. Sensitive code and data require an approved provider agreement and an OS-level workspace sandbox. `brand_rights_confirmed` remains **false** until written authorization is received. Existing SAFWA-016 source-only test evidence does not validate SAFWA-017.

## Release policy
Arabic Quran verses must never be invented. Validate source SHA, counts and exact characters against trusted independent data and secure two separate reviews before approving `assets/data/quran_verified.json`. Never activate by merely changing flags. Release remains disabled pending security, copyright, religious, and device checks.
