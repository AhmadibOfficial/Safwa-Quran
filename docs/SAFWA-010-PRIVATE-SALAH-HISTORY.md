# SAFWA-010 — Private Weekly Salah History

## Delivery: source-only, no emulator

A new **Weekly Salah Journal** route in the Safwa Companion hub.

- Shows seven consecutive **device-local** civil days, Monday through
  Sunday; supports crossing month and year boundaries.
- Displays only the five already-supported daily Salah names.
  Stored checkmarks represent **only actions the user explicitly marked**.
  Blank checkmarks mean **not recorded**, never that a prayer was missed,
  that it was obligatory in a particular personal circumstance, or that
  an assessment or religious ruling has been made.
- Expand a day to mark/unmark a prayer. Reuses `LocalSalahJournal.toggle`
  and `LocalSalahJournal.read` — the same local SharedPreferences keys
  as the original single-day Salah Journal; no duplicate data store.
- Previous/next week and jump to the current device-local week.
- Header reports only the number of **personal entries recorded**, not
  a score, perfection percentage, streak, moral label or attendance rate.
- Works without GPS, network, authentication, analytics, background
  processing or new packages; it does not access Quran text.
- Does not export or share private Salah records with the OS clipboard
  or other applications. The existing Privacy & Data action continues to
  delete `safwa_salah_...` records along with other Safwa preferences.

## Code and tests

- `lib/salah_history.dart`: immutable daily read snapshots, private
  local-history service, read/edit Flutter screen, neutral descriptions.
- `lib/companion_features.dart`: add the hub navigation tile.
- `test/salah_history_test.dart`: nine source-level test definitions,
  covering seven-day boundaries, explicit marks, malformed data,
  immutable snapshots, selective deletion, date bounds, updates,
  widget neutral-state text, local UI toggle, and hub routing.

Tests have **not** yet been executed by the assistant; run the Kali
source-only gate to validate the new branch.

## Reuse and privacy

Local storage is app-managed, not encrypted end-to-end. A person with
access to device backups or to an unlocked device may read app data.
No prayer history leaves the device by this feature's design. Safwa
should provide full privacy policy and restore/export review separately
before any public launch.

## Safe Kali validation

```bash
cd ~/Safwa-Quran
git status --short --branch
git fetch origin
git switch --track origin/feature/safwa-010-private-salah-history
bash -n scripts/verify_source_only.sh
bash scripts/verify_source_only.sh --offline
```

If the local branch already exists, stay on it and `git pull --ff-only`
rather than recreating it.

**Do not** use `git clean`, `git reset --hard`, `git stash pop`,
`flutter clean`, or Android-specific commands. Existing untracked
`android/`, `ios/`, `pubspec.lock`, user's modified
`test/prayer_times_test.dart`, and earlier stash must stay intact.
The test gate intentionally does not launch an emulator, run Gradle or
build an APK.

## Verification and release boundaries

- Previous SAFWA-009 developer evidence: 11/11 Python tests passed,
  26/26 Flutter tests passed, analyzer clear, source-only gate PASS.
  This validates its prior commit, **not** the newly added SAFWA-010 code.
- Quran reader `quran_reader_enabled=false`; release
  `public_release_enabled=false`. Authenticated reviews by genuinely
  independent qualified Hafs scholars remain **0/2**.
- New private journal is a source-only draft until Kali analyzer/tests
  are run and reviewed. No merge, deployment or app-store release.
