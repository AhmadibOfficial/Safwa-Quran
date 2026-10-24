# SAFWA-015 — Transactional Local Storage & Device Recovery Plan

**STATUS: DEVELOPMENT DRAFT.** SAFWA-014's 72 Flutter and 11 Quran Python tests passed on Kali on 2026-10-24. SAFWA-015's added SQLite code and tests have **NOT** yet been run on Kali; no process-kill, device restart, storage-failure, iOS, or independent audit results exist. Public release and Quran reader stay blocked.

## Design decision

The existing production-path preferences are still in `SharedPreferences`: prayer settings, Quran bookmarks, Salah journal, Tasbih, language, Companion pins, and backup/restore. A SQLite-only restore with remaining SharedPreferences readers would create split-brain state. Therefore **do not switch any existing UI, app startup or production restore to SQLite in this milestone**. Never claim the SharedPreferences undo journal from SAFWA-014 has been replaced yet.

SAFWA-015 adds `lib/safwa_sqlite_store.dart`, a **separate, opt-in, file-backed SQLite prototype** containing a single validated allowlisted preference snapshot. A replacement occurs through SQLite's transaction API, so a thrown error before commit rolls back the entire update in the database. It is opened with `journal_mode=WAL` and `synchronous=FULL`; startup verifies those pragma values and the stored Safwa checksum, failing closed if either check fails. SQL APIs use bind parameters for values, with no dynamic SQL identifiers from import data.

**Known limitations**
- Existing SharedPreferences data and the SAFWA-014 plaintext recovery journal are unaffected; no automatic migration or deletion.
- The SQLite database holds sensitive preferences **in plaintext** under the app sandbox. It is NOT SQLCipher or encrypted-at-rest. Device-level encryption, Android/iOS backup policies, data-at-rest risks and secure erase remain to be reviewed.
- SQLite WAL/FULL semantics provide transaction atomicity and improved durability under supported filesystems, not a universal promise for flash controllers, OS backup/restore, corrupt storage, device loss, or catastrophic hardware failure. Verify actual device paths and filesystem behaviour. See official SQLite pragma docs and platform specifics.
- A single snapshot row is simple but is not suitable for unlimited future data; journal/history growth, query concurrency, and migration performance need profiling.
- No Android build, iOS build, emulator, device test or live app integration is authorized by this PR.

## Implemented isolated interfaces

- `SafwaSqliteStore.open()`: explicitly opens named file through an injected `DatabaseFactory`; verifies WAL/FULL and existing backup integrity.
- `readValues`, `exportValidatedJson`: read validated Safwa-only snapshot.
- `setPreference`, `removePreference`: typed, allowlisted, single-transaction changes.
- `restoreValidatedJson`: strict backup validation before a SQLite transaction and explicit consent; deterministic pre-commit fault injection supported in tests.
- `restoreEncryptedJson`: authenticates and validates the existing SAFWA-012 ciphertext before one SQLite transaction. Does not update SharedPreferences or the UI.
- `stageLegacyJson`: explicit, **copy-only**, refuses overwriting a nonempty SQLite snapshot; never erases or synchronizes the old store.
- `close()`: closes the FFI/mobile-backed database.
- Legacy `LocalSafwaBackup.encodeValidatedSnapshot` and immutable `SafwaBackupPreview.validatedValues` let both backends share the existing strict schema and allowlist.

## Design acceptance gates

| Gate | Evidence required | Status |
|---|---|---|
| D1 | Dart 3.10-compatible dependency resolution on Kali | Not run |
| D2 | SQLite WAL/FULL settings verified with file-backed FFI | Test defined, not run |
| D3 | Failed transaction rolls back completely; state persists after close/reopen | Tests defined, not run |
| D4 | Successful restore replaces exactly the allowlisted state | Test defined, not run |
| D5 | Encryption, unknown keys, forbidden verse references, no consent | Tests defined, not run |
| D6 | Copy-only legacy staging, no loss of user SharedPreferences values | Test defined, not run |
| D7 | **Migrate ALL live preference consumers to canonical SQLite reads/writes** with old-store archive/recovery and no split-brain; repeatable migration/version upgrades | Not implemented; blocks live switch |
| D8 | **Real process termination/relaunch on Android AND iOS** with before/after snapshots for all commit boundaries | Not run; requires approved device setup |
| D9 | Real or controlled low-storage, disk-full, OS kill/restart, app-version upgrade, and corrupted DB handling | Not run; requires approved device setup |
| D10 | Independent AppSec/crypto and privacy/accessibility reviewers attest exact SHA and outstanding issues | Not obtained |
| D11 | Existing Quran content locks and public release policy remain OFF | Enforced by inherited source-only gate; re-test pending |

## Run source-only validation on Kali WITHOUT touching the primary worktree

Your primary checkout has known local changes: modified `test/prayer_times_test.dart`, untracked `android/`, `ios/`, and `pubspec.lock`. A **separate worktree** avoids overwriting or modifying them when new dependencies resolve.

```bash
cd ~/Safwa-Quran || exit 1
git status --short --branch
git fetch origin

REVIEW="$HOME/Safwa-Quran-015-review"
if [ -e "$REVIEW" ] || [ -L "$REVIEW" ]; then
  echo "STOP: Review path already exists; inspect it first."
else
  git worktree add --detach "$REVIEW" \
    origin/feature/safwa-015-transactional-sqlite-foundation
fi

# Continue only if the worktree was freshly created or independently verified.
cd "$REVIEW" || exit 1
flutter --version
dart --version
flutter pub get       # New SQLite deps need first-time online resolution.
flutter analyze
flutter test --reporter expanded test/safwa_sqlite_store_test.dart
bash scripts/verify_source_only.sh --offline
git diff --check
git status --short --branch
```

On Kali, FFI tests also require a working system SQLite shared library (`libsqlite3`). If dependency resolution or library loading fails, stop and report the exact error; **do not purge SDKs, alter global Flutter, delete caches, reset repositories, or install packages automatically**. Do not touch the primary worktree to remediate.

## Android / iOS device verification protocol (PREPARATION ONLY; NOT EXECUTED)

Before hardware testing, reviewers must approve a separate test-app harness that exclusively uses **synthetic data** and a disposable database. Test sequence for both OSes:

1. Record model, OS build, app version, database schema, SQLite compile/runtime version, journal mode, sync mode, available disk, and DB file path within sandbox (not exported personal files).
2. Prepare synthetic A/B snapshot values with a cryptographic digest; verify that all 114 Quran catalog counts still pass without exposing unreviewed Quran text.
3. Start restore; inject checkpoints before the SQL UPDATE, inside the transaction after UPDATE, and immediately after COMMIT. Force-stop/terminate test app while checkpoint holds, using supported debug/test tooling. **Do not kill unrelated apps or real user data**.
4. Relaunch the test app, reopen the same database file, and compare actual snapshot SHA-256 against exactly A (pre-commit) or B (post-commit). A partial/mixed snapshot is a **BLOCKER**. Repeat multiple times per checkpoint and on both OSes.
5. Exercise low-disk/SQLITE_FULL using an isolated quota or controlled test storage fixture; do not fill the user's primary phone or development disk. Verify rollback without data loss. Include journal/WAL sidecar preservation and process recovery.
6. Corrupt a **copy of a disposable test database**, never the live Safwa store; verify safe failure and preserve forensic evidence for review. Test one unsupported schema upgrade/downgrade without silently deleting the DB.
7. Measure latency, memory, data retention, OS backup behaviour, screen-reader and restoration warnings. Verify legacy consumer cutover only after D7.
8. Produce reproducible timestamped results: exact commit SHA, devices/OS, command transcript, checksums, before/after rows, failure injection point, reviewer signature, and blocking defects.

Android force-stop examples require a **reviewer-supplied disposable test application ID** and install/debug approval; iOS requires its own Xcode/XCTest harness. This repository's existing local `android/` and `ios/` are untracked and must never be overwritten by test scaffolding.

## Migration to canonical SQLite is a separate required code gate

1. Inventory all direct SharedPreferences reads/writes in `lib/main.dart`, `lib/prayer_times.dart`, `lib/prayer_week.dart`, `lib/companion_core.dart`, `lib/companion_features.dart`, `lib/companion_directory.dart`, and backup/recovery.
2. Move each consumer behind a shared storage interface with injected backend; confirm original widget tests still pass.
3. Stage validated legacy preferences into a new SQLite DB; compare counts and checksum. Keep original legacy data and encrypted backup until migration verified.
4. Make SQLite the **single writer and reader** at a single validated activation boundary; eliminate old restore and plaintext clipboard entrypoints. Block any partial migration; avoid simultaneous writes.
5. Confirm privacy deletion, user consent and all journal/reminder/bookmark behaviours. Repeat crash testing after actual UI wiring.
6. Only after D7–D10 evidence and owner approval may the implementation replace SAFWA-014's temporary journal. Do not remove the journal until no consumer depends on it.

## Non-negotiable Safwa restrictions

- No Quran text activation, religious content fabrication, Adhkar/Hadith import, audio licensing bypass, GPS, notification permissions, cloud sync, release or publication.
- Independent qualified Hafs scholars: **0/2 authenticated approvals**; Quran reader and public release remain **BLOCKED**.
- PR stays **DRAFT** and unmerged until acceptance and explicit owner decision.
