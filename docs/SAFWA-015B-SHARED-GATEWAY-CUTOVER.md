# SAFWA-015B — Shared preference gateway and controlled-cutover barrier

**Development draft. Nothing has been executed on Kali for this branch.** The parent SAFWA-015 SQLite adapter and migration rehearsal also remain unverified on Kali. Public release and Quran reader remain BLOCKED.

## Code delivered

All direct Safwa preference consumers listed in the SAFWA-015 repository inventory have been routed through `lib/safwa_preferences.dart`, including `lib/local_backup.dart` and its SAFWA-014 recovery journal. The gateway preserves synchronous typed reads and asynchronous write/removal methods on top of the existing `SharedPreferences` plugin, so the current app behavior and local values do not intentionally change.

- `SafwaPreferences.getInstance()` **always** returns the legacy SharedPreferences implementation. There is **no production SQLite activation flag, marker or implicit migration.**
- `SafwaPreferences.sqliteForVerification(store)` explicitly wraps an independently opened, disposable `SafwaSqliteStore` for unit tests. It does not change any global state or other app consumers.
- Shared typed contract: `getKeys`, `containsKey`, `get`, `getString`, `getBool`, `getInt`, `getDouble`, `getStringList`, typed `set*` and `remove`. No destructive generic `clear` API.
- Existing legacy storage is still the authoritative source. Missing or unknown keys are not automatically coerced, restored or deleted.
- Existing backup and restore consent, recoverable-journal behavior and the encrypted-export layer remain on the legacy backend.

This does **not** mean a full canonical cutover has been achieved. It is a preparation step to allow safe backend injection and consumer tests while keeping all production work on the original storage path. A `getInstance()` override, runtime SQL activation or preference switch **must not be added until all gates below are satisfied.**

## Tests added but not run

`test/safwa_preferences_test.dart` has five source-defined cases:
1. Default app gateway preserves old SharedPreferences reads/writes and unrelated app secrets.
2. Original encrypted-backup scope's plaintext inner backup remains allowlisted, not a wholesale prefs export.
3. List reads return detached copies, preventing mutation without a write.
4. An isolated SQL session supports typed reads/writes, rejects release keys and leaves the live legacy store unchanged.
5. An incomplete SAFWA-014 recovery journal continues to block unsafe export.

When combined with 72 parent SAFWA-014 tests, 9 SQLite tests, 5 migration rehearsal tests, **expected** total is 91 Flutter tests. This is a projected count, **NOT a passing result**. Exact-commit Kali execution is mandatory.

## Controlled-cutover algorithm to implement AFTER verification

An actual live SQLite cutover requires a distinct, independently reviewed migration state machine. Required steps:

1. **Preflight:** Run 91 current tests and the 11 Python Quran integrity tests on a clean isolated checkout; record SHA, dependency lockfile and platform compatibility. Obtain product-owner permission for a disposable test-app harness.
2. **Freeze writes:** Acquire a process-wide gateway write barrier affecting **existing session objects as well as newly requested sessions**; deny or await all preference writes, backup restores, privacy erase and recovery operations during staging. Handle other isolates/platform restarts. Without a verified barrier, source-stability digest is only a spot check.
3. **Recover before stage:** Verify there is no unfinished SAFWA-014 legacy undo journal. Fail closed if recovery cannot be completed.
4. **Stage:** Validate and copy only allowlisted current legacy keys to an isolated SQLite file; never delete source values or unrelated keys. Verify key count, canonical SHA, types and values.
5. **Durable commitment:** Store a migration version, source hash and single-writer activation state in a SQLite transaction together with the validated snapshot. Ensure device restart selects the committed backend *before any consumer reads*. A crash before activation must leave legacy as canonical; after activation it must remain SQLite until an explicit rollback protocol with a verified snapshot.
6. **Cutover:** Make all readers/writers, encrypted backup/restore, preference deletion and recovery route to canonical SQLite using the same gateway. Prevent stale legacy sessions from continuing to write. Do not dual-write or silently fall back to SharedPreferences after an SQLite error.
7. **Crash testing:** On a **disposable** Android/iOS app and DB, force-stop before/inside/after staging and activation and verify that restart sees one complete state, never split-brain. Exercise low storage, permission/IO failure, WAL sidecars, DB corruption, app upgrade and recovery without erasing forensic evidence. Never fill the user's system disk or touch their existing untracked `android/` and `ios/` projects.
8. **Independent signoff:** Obtain actual qualified AppSec/crypto reviewer findings and separate privacy/accessibility assessment on the final exact SHA. The SQLite file and legacy WAL snapshot both contain sensitive data in plaintext; evaluate device encryption and OS backup policy. Independent Quran scholars remain a separate mandatory 0/2 gate.

**There is no currently approved cutover command.** Do not use `dart-define`, developer menus, direct edits to SharedPreferences, or SQLite pragma manipulation to bypass these prerequisites.

## Safe isolated Kali validation

Use the separate parent worktree method. If `$HOME/Safwa-Quran-015b-review` already exists or is a symlink, STOP and inspect rather than replacing it.

```bash
cd ~/Safwa-Quran || exit 1
git status --short --branch
git fetch origin || exit 1

REVIEW="$HOME/Safwa-Quran-015b-review"
if [ -e "$REVIEW" ] || [ -L "$REVIEW" ]; then
  echo "STOP: isolated review path already exists."
  exit 1
fi
git worktree add --detach "$REVIEW" \
  origin/feature/safwa-015b-preference-gateway || exit 1

cd "$REVIEW" || exit 1
flutter pub get || exit 1
flutter analyze || exit 1
flutter test --reporter expanded \
  test/safwa_preferences_test.dart \
  test/safwa_sqlite_store_test.dart \
  test/safwa_migration_rehearsal_test.dart || exit 1
bash scripts/verify_source_only.sh --offline || exit 1
git diff --check
git status --short --branch
git rev-parse HEAD
```

First-time dependency downloads require network; SQLite FFI tests require `libsqlite3`. Preserve primary worktree modifications `test/prayer_times_test.dart`, untracked `android/`, `ios/`, `pubspec.lock` and stashes. If any gate fails, do not edit the user's global toolchain, delete caches, reset branches, clean directories, build APKs or run emulators. Return the log for targeted fixes.

## Release restrictions

- New SQLite adapter / gateway are NOT production-approved.
- No Quran reader activation; release remains BLOCKED, independent Hafs scholars 0/2.
- No new OS permissions, cloud data, analytics, automated religious content, audio or notification claims.
- Draft stacked PR only. No merge until tests, device recovery and independent reviewers plus explicit owner approval.
