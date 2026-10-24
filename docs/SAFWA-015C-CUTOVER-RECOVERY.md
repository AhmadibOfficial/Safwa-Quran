# SAFWA-015C — Controlled SQLite Cutover & Fail-Closed Recovery

**Status: DRAFT source implementation / Kali tests NOT YET EXECUTED.**
Based on SAFWA-015B commit `7c3356df1993e615139a9f894cde06cdaccb05ae`, owner-tested with **91 Flutter tests, 11 Python Quran integrity tests and clean analyzer** on 2026-10-24. Those results do **not** validate SAFWA-015C.

## Implemented safety model

This branch introduces an explicit **in-process, test-only review controller**, not a shipping activation mechanism:

- `SafwaSqliteStore` schema v2 adds `safwa_activation` containing one strictly validated `legacy` or `sqlite` state and optional source SHA-256.
- `activateValidatedLegacy` accepts a validated allowlisted snapshot, verifies that any staged SQLite data is empty or matches it, and writes **the snapshot and activation marker in one SQL transaction**. Version-1 SQL files upgrade via `onUpgrade` without deleting the snapshot.
- `SafwaCutoverController.openForIsolatedReview` reads the SQLite activation record before selecting its canonical backend. A persisted `sqlite` marker selects SQLite on restart and **never falls back** to altered/stale SharedPreferences; absent/corrupt/unknown markers fail closed.
- During explicit cutover, controller freezes gateway operations, waits for already-accepted routed writes, and captures only allowlisted legacy data. Tests inject a failure before the snapshot update, after the snapshot update, after the activation marker but **before commit**, and after commit before the in-memory switch. Failed SQL transactions preserve legacy as canonical. If the SQL commit completed but code then fails, the in-memory controller locks itself; restarted controller discovers persisted SQLite activation.
- `SafwaPreferences` performs dynamic forwarding to the review controller on **every access**, including handles acquired before the controller was installed. Both original pages and LocalSafwaBackup use the same typed facade. The production `SafwaPreferences.getInstance()` continues to use SharedPreferences because `main()` **does not install** any cutover port or SQL bootstrap.
- Post-activation test-only backup restore calls a single SQLite transaction rather than the obsolete per-key undo journal. The existing encrypted import still authenticates through the original engine, then delegates into the canonical restore.
- Post-activation privacy erasure replaces the SQL snapshot with an empty allowlisted snapshot in one transaction. **Legacy values are intentionally retained** during rehearsal. This is NOT sufficient to claim comprehensive personal-data erasure in production; independent privacy review must set a safe retention/removal policy.

### Strict non-guarantees and security limitations

The write barrier covers only application operations routed through the **same Dart process and the installed review controller**. It does not block native code, other isolates/processes, direct calls to `SharedPreferences.getInstance()`, platform backup tooling, concurrent untracked Flutter instances, or OS storage changes. It also cannot make multi-step UI read/modify/write actions such as Tasbih increments serializable: review optimistic concurrency, app lifecycle and atomic update design before shipping. **Do not deploy or enable this code as a production cutover.**

SQLite WAL + synchronous FULL may provide stronger durability, but **Dart fault injection does not prove real OS process-kill, filesystem flush, power-loss, iOS/Android isolation, storage corruption or low-storage safety**. The SQLite file and retained legacy settings include sensitive Salah records in plaintext; they are not encrypted-at-rest by this branch. Backup policy, secure erasure, key management, and independent AppSec/privacy/accessibility review remain blockers.

**Never introduce a shipping toggle** (environment variable, debug route, UI action, feature flag) to activate this review controller while its external gating requirements remain unmet.

## Test suite — defined, not run

`test/safwa_cutover_test.dart` (11 cases):
1. Legacy remains canonical before activation.
2. Snapshot and marker commit together; a session obtained earlier reads/writes the new store.
3. A thrown failure after snapshot update rolls back and leaves legacy canonical.
4. A thrown failure after SQL commit locks the session; new runtime chooses SQL, not changed legacy.
5. Barrier prevents new reads and writes while staging waits.
6. Rebooting test controller after a successful migration reads SQL-only values.
7. Existing user restore workflow writes the canonical SQL store, not the legacy undo journal.
8. SQL privacy erase atomically empties the SQL snapshot; retained legacy is documented.
9. Missing explicit consent blocks migration.
10. Unresolved legacy undo journal blocks migration, persists unchanged.
11. After activation, an old legacy undo journal is not replayed into SQL.

Expect **102 Flutter tests** if this branch only adds the 11 new tests to 91 inherited passing SAFWA-015B tests, plus the 11 Python integrity checks. **This is an expected count, not a test result.**

Tests use only uniquely generated disposable filesystem SQLite DBs and mock SharedPreferences, not private data or native apps.

### Source-only validation on Kali

Protect local primary repo changes: modified `test/prayer_times_test.dart`, existing untracked `android/`, `ios/`, `pubspec.lock` and stashes. **Do not use `git clean`, `git reset --hard`, force checkout, delete review worktrees or destroy Docker volumes.**

```bash
cd ~/Safwa-Quran || exit 1
git status --short --branch
git fetch origin || exit 1

REVIEW="$HOME/Safwa-Quran-015c-review"
if [ -e "$REVIEW" ] || [ -L "$REVIEW" ]; then
  echo "STOP: SAFWA-015C review path already exists."
  exit 1
fi
git worktree add --detach "$REVIEW" \
  origin/feature/safwa-015c-controlled-cutover || exit 1
cd "$REVIEW" || exit 1

flutter pub get || exit 1
flutter analyze || exit 1
flutter test --reporter expanded \
  test/safwa_cutover_test.dart \
  test/safwa_preferences_test.dart \
  test/safwa_sqlite_store_test.dart \
  test/safwa_migration_rehearsal_test.dart || exit 1
bash scripts/verify_source_only.sh --offline || exit 1
git diff --check
git rev-parse HEAD
git status --short --branch
```

If Flutter tests, SQL upgrade, FFI or package resolution fail, keep the log and stop. No emergency installation, emulator, Android/Gradle build, iOS build, cache purge or native filesystem manipulation is part of this source-only step.

## External acceptance — remains blocked

1. **Isolated test pass:** exact commit SHA Kali analyzer, 102 Flutter tests, 11 Python checks, policy lock and worktree state verified.
2. **Full production bootstrap:** after formal approval, startup must establish a single canonical runtime before any widgets, plugins or background isolates can access Safwa state. No cold-start legacy fallback if an activated SQL DB is absent or corrupt. Cross-isolate synchronization or fail-closed isolation is mandatory.
3. **Concurrency:** enforce all writers (including pre-existing handles, imported restore, journal updates, read-modify-write counters, deletion), and prevent direct SharedPreferences writes. Add process, isolate, OS restart and app-version concurrency tests. A mere in-process frozen flag is not enough.
4. **Migration:** keep original legacy data encrypted or isolated appropriately until confirmed recovery; verify full equality and policy-safe erasure of legacy after the approved retention period. No permanent plaintext shadows and no loss of keys outside the allowlist.
5. **Device:** approve a disposable Android/iOS harness with synthetic A/B snapshots and deliberate process termination before staging, between snapshot and marker (inside SQL txn), after SQL commit, during restart, during low-storage/SQLITE_FULL. On restart require full A (before commit) or B (after commit), NEVER mixed; collect WAL/synchronous pragma evidence and checksum records.
6. **Independent reviews:** genuine qualified AppSec/cryptography and separate privacy/accessibility reviewers must review exact final commit and device evidence. No fabricated review signoffs.
7. **Religious policy:** Quran verified-reader and public release stay BLOCKED. Independent qualified Hafs scholarly approvals remain **0/2**. No unreviewed religious content unlocks.

Current stage remains **source implemented / Kali unvalidated**, draft PR unmerged, production cutover off.
