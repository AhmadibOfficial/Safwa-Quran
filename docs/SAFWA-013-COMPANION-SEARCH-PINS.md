# SAFWA-013 — Accessible Companion Search & Pinned Tools

## Overview
Adds an offline searchable directory for all **13 existing Companion tools**
without unlocking Quran Arabic, Adhkar/Du'a, recitation audio or unreviewed
religious content.

The Companion tab now provides:
- Search by title and description, matching all words case-insensitively.
- Optional star/pin action on each item, with pinned tools sorted above normal
  tools. Original editorial order remains stable inside each group.
- Local persistence of pinned tool IDs using `safwa_companion_pins`;
  there is no account, cloud sync, notifications, analytics or GPS.
- A live-region count of visible and pinned items, accessible pin/unpin
  tooltip labels, clear empty-result feedback, and a separate navigation
  action. Tapping the pin does **not** open the tool.
- The existing source-gated libraries are still gated behind their
  verified-source placeholders, even if searched or pinned.

## Privacy, backup and content safety
Pin IDs are local navigation preferences, not prayer attendance, worship
scores or endorsements. They are wiped by the current Safwa data-delete
action, as they begin with `safwa_`.

SAFWA-011's strict preference allowlist now recognizes only
`safwa_companion_pins` with known IDs and no duplicates. Older backups
remain valid without this optional key. Restores cannot create arbitrary
routes or override Quran/release approval. SAFWA-012's encrypted backup
internally reuses this same validated preferences allowlist.

Source-lock/release policy files are untouched. No content licensing or
scholarly approval is implied.

## Code changes
- `lib/companion_directory.dart`: stable static tool IDs/descriptions,
  pure filtered ordering, local pin repository.
- `lib/companion_features.dart`: stateful Companion Hub, accessible search,
  separate pin and navigate controls, fail-closed known-ID routing.
- `lib/local_backup.dart`: allowlisted pin IDs for backup and restore.
- `test/companion_directory_test.dart`: ten unit/widget test definitions
  for stable routes, search, pin order/persistence, filtering invalid IDs,
  backup round-trip, invalid backup import rejection, UI search, pin interaction
  and locked religious content.
- `config/feature_status.json`: accurate draft-stage tracking.

## Local validation — no emulator required
The owner previously reported that SAFWA-011 passed **11 Python tests,
44 Flutter tests and the analyzer** on Kali. SAFWA-012 introduced
`cryptography:^2.9.0` but its five new tests have **not yet been confirmed
passing on Kali**; this SAFWA-013 branch is stacked on the SAFWA-012 draft,
so an online dependency resolution may be needed once.

Run on Kali:

```bash
cd ~/Safwa-Quran
git status --short --branch
git fetch origin
git switch --track origin/feature/safwa-013-companion-search-pins
flutter pub get
bash scripts/verify_source_only.sh --offline
git status --short --branch
```

If the branch already exists, switch to it, then `git pull --ff-only`.
If Git blocks checkout, **stop**, inspect conflicts and preserve
`test/prayer_times_test.dart` modifications, `android/`, `ios/`,
`pubspec.lock`, all project assets and stashes. No `git reset --hard`,
`git clean`, `flutter clean`, Gradle cache changes or emulator.

**Expected if tests pass:** Existing baseline 44 Flutter tests +
5 SAFWA-012 encryption tests + 10 SAFWA-013 directory tests = 59 tests.
This is a goal, **not a claim of verification**.

## Release remains blocked
Quran reader flag remains disabled, public release flag disabled;
independent approved Hafs scholar signoffs authenticated **0 of 2**.
Draft branches must not be merged or published automatically.
