# SAFWA-015D — Device Durability, Concurrency & Recovery Validation

**Current state:** Source-defined tests/harness only. **Not yet run on Kali or physical devices.**
Parent SAFWA-015C is verified at SHA `ddbae89a2fe5b43e64c298313891b7d69a30ab76` on Kali: **106 Flutter tests**, **11 Quran integrity tests**, **0 analyzer issues**. Those figures do NOT validate this branch.

## Implementation boundary

This branch does not change `main.dart` and DOES NOT install or enable a production SQLite cutover. Test code never uses production user accounts, real Salah data, app live databases, or religious content policy toggles.

### SQLite schema v3 and coordination

- `safwa_snapshot.revision` is an integer >=0; schema v1 and v2 upgrade in place to v3, retaining the original archive and activation state.
- Separate SQLite connections are requested with `singleInstance:false` to exercise actual cross-connection SQL contention, rather than accidentally reusing the same in-memory handle.
- Once `safwa_activation.state == sqlite`, **old unfenced** `setPreference`, `removePreference`, `restoreValidatedJson`, and `stageLegacyJson` cannot change the canonical SQL snapshot.
- `mutateCanonicalForReview` atomically verifies activation, reads the committed revision and validated snapshot, checks the caller's expected revision, validates the next allowlisted snapshot, writes it and increments the revision in ONE SQLite transaction. Stale calls throw and must **not** retry blindly; the caller needs a refreshed canonical snapshot. Transaction exceptions roll back archive **and** revision.
- The isolated `SafwaCutoverController` now uses these fenced mutations even for backup restoration and privacy deletion. On a stale revision, I/O error or invalid write it locks itself rather than serving outdated cache as canonical.
- Database open validates WAL + FULL and SQLite `PRAGMA quick_check` plus Safwa's snapshot checksum/allowlist. An opt-in `requireExistingForReview` option rejects missing DB files before automatic SQLite creation.
- `SafwaLegacyRetention.auditForReview` reports only key count, source-hash match and `approvedToEraseLegacy=false`. It never returns raw values, deletes a key, marks backups safe, or implies secure erase.

**Crucial:** These changes strengthen the **activated SQL backend** against competing transactional writers but DO NOT create a process-wide or OS-wide lock on **legacy SharedPreferences** during the initial cutover. Nor do synchronous cached widget reads automatically detect another isolate's update. Until a trusted bootstrap authority, cross-isolate refresh/invalidation and user-approved privacy lifecycle exist, **shipping cutover remains blocked**.

### New synthetic local tests (NOT EXECUTED)

- `test/safwa_015d_concurrency_test.dart` — 7 new FFI cases: two independent SQL connections reject stale writes, preactivation write guard, postactivation unfenced API rejection, deterministic transaction failure with complete rollback, existing-only missing DB rejection, corrupt snapshot fails closed without erasure, schema-v2 upgrade preserves content.
- `test/safwa_015d_retention_test.dart` — 3 new FFI cases: refusal before activation, unchanged retained shadow with no erase authority, postactivation divergence and undo-journal failure guard.
- Original SAFWA-015C 15 cutover tests and preceding suites remain unchanged except for version-name label updates. **Expected full Flutter count: 116** (106 verified inherited + 10 unexecuted), plus **11 Python Quran tests**. This is a target, **not a passing result**.

## Disposable Android/iOS operator harness (NOT RUN)

`integration_test/safwa_015d_device_test.dart` is a deliberately *manual*, phased `integration_test` entrypoint with no shipping import or automatic invocation in the existing `flutter test` gate. It uses only:

- Test-app sandbox database folder from `sqflite.getDatabasesPath()`.
- Fixed synthetic file `safwa015d-synthetic-review-only.sqlite3`.
- Synthetic city `kaduna`, Tasbih `23`, Surah bookmark references `1,2` and Fajr reminder preference.
- No external source files, permissions, live Quran reader, personal profiles, real backups, network API, or cloud sync.

**Do not run against an existing production Safwa app ID or its data.** Only after explicit owner authorization, use a separately identified, disposable test app created in a separate disposable worktree/container. The source repo does not include production-ready `android/` and `ios/` scaffolds. On iOS, a macOS/Xcode/device environment and platform signing will be required. Do not generate platforms into `~/Safwa-Quran` or delete any existing worktrees. Do not run destructive `flutter clean`, `git clean`, `git reset --hard`, recursive cache purges, database/volume cleanup, or alter system disks. Preserve any native project already present in the owner's checkout.

The harness rejects unspecified phases and refuses to overwrite a pre-existing synthetic file. The documented phase names are:

| Phase | Expected behavior |
| --- | --- |
| `prepare` | Creates one empty synthetic SQL database and verifies activation remains legacy |
| `verify-legacy` | Reopens **existing** database, expects legacy state and empty snapshot |
| `hold-before-commit` | Hangs **inside an uncommitted transaction after marker write** for a deliberate operator force-stop of only the disposable app |
| `hold-after-commit` | Commits synthetic snapshot and marker then hangs for deliberate operator force-stop before Dart updates any in-memory app state |
| `activate` | Activates synthetic content normally; use only after a fresh prepare or verified pre-commit rollback |
| `verify-active` | Reopens existing DB and asserts committed marker, synthetic values and checksum |
| `cleanup` | **Explicit** deletion of this test-owned database path only; cannot securely erase flash/OS snapshots |

**Manual test sequences (after separate test-app installation has been authorized):**

1. Pre-commit restart: `prepare` → `verify-legacy` → `hold-before-commit` → operator terminates the **disposable app only** → `verify-legacy` must still see pre-commit state. Record actual device, OS, timestamps, app ID, DB path policy and evidence; redact private data and auth tokens.
2. Post-commit restart: `prepare` → `hold-after-commit` → operator terminates the test app → `verify-active` must see **all** synthetic values; never read legacy fallback.
3. Clean commit: `prepare` → `activate` → `verify-active`.
4. Only after recording evidence: `cleanup` must target that specific disposable sandbox. The test runner may uninstall/reinstall an app between invocations; verify app data actually persisted before claiming device durability.

At each stage invoke the harness explicitly (illustrative command after approved disposable Android/iOS scaffold exists):

```bash
flutter test integration_test/safwa_015d_device_test.dart \
  -d <TEST_DEVICE_ID> \
  --dart-define=SAFWA_015D_PHASE=prepare
```

**DO NOT execute these phase commands now without an authorized disposable test-app environment.** The `hold-*` phases intentionally do not complete; operator must terminate the test app rather than the owner's shell/IDE or unrelated applications. Android `adb shell am force-stop <DISPOSABLE_APP_ID>` can be used only when the exact test package is known. On iOS coordinate the equivalent app termination from the signed test environment. Do not guess package names or use a blanket `pkill`. Verify app data survival across test runner launches; some runners reset test app state.

### Real-world durability and failure-injection review (STILL PENDING)

This source adds only *simulated* transactional failures. It **does not** exercise true `SQLITE_FULL`, filesystem pressure, OS flash sync, torn WAL writes, file truncation, background isolate writes, process death outside intentional operator tests, iOS Keychain backup settings, Android Auto Backup or secure erasure.

Required independent test acceptance on **disposable devices** and test data:

- Record actual WAL and synchronous FULL settings, `quick_check`, DB version/revision, source SHA and activation before and after **operator-controlled process termination**.
- Force termination pre/post transaction and observe exactly one coherent state; never split-brain. On Android and iOS separately collect test-runner logs and native app lifecycle records.
- Reproduce storage-full conditions in a controlled platform test sandbox without filling the owner's system partition or writing huge random files. Failure before SQL commit must retain old archive, activation and revision. No automatic attempts at real disk exhaustion.
- Corrupt/truncate only **duplicate disposable test databases** and verify fail-closed startup; never tamper with live-user SQLite/WAL/SharedPreferences.
- Independently run two app processes/isolates to prove that native or legacy writers are blocked before cutover and that canonical reads are invalidated after external SQL writes. SQL revision rejection alone is not enough.
- Resolve safe legacy-data retention: encrypted/private backup policy, retention limits, user consent, restoration criteria, OS backup exclusions, privacy notices, Android/iOS platform encryption, flash forensic limitations and verified deletion approach. `approvedToEraseLegacy` must remain false until reviews.
- Independent AppSec/cryptography and separate privacy/accessibility reviewers should sign off on the **exact final SHA**, not a draft estimate. No fabricated review approvals.

**Public reader / release:** BLOCKED. Independent qualified Hafs scholar approvals remain **0/2**, no Quran text unlocking or live data migration. PRs remain DRAFT/unmerged.

## Non-destructive Kali source-only verification

Run from a **child Bash** in a new, clean `$HOME/Safwa-Quran-015d-review` directory. If that exact path exists (including symlink), STOP; do not overwrite or destroy it.

```bash
bash <<'BASH'
set -Eeuo pipefail
trap 'r=$?; if [ "$r" -ne 0 ]; then echo "Stopped (code $r). Terminal remains open."; fi' EXIT
cd "$HOME/Safwa-Quran"
git fetch origin
REVIEW="$HOME/Safwa-Quran-015d-review"
if [ -e "$REVIEW" ] || [ -L "$REVIEW" ]; then
  echo "STOP: Review directory already exists."
  exit 1
fi
git worktree add --detach "$REVIEW" origin/feature/safwa-015d-device-concurrency-validation
cd "$REVIEW"
flutter pub get
flutter analyze
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/safwa_015d_concurrency_test.dart \
  test/safwa_015d_retention_test.dart \
  test/safwa_cutover_test.dart \
  test/safwa_preferences_test.dart \
  test/safwa_sqlite_store_test.dart \
  test/safwa_migration_rehearsal_test.dart
bash scripts/verify_source_only.sh --offline
git diff --check
git status --short --branch
git rev-parse HEAD
BASH
```

Do not commit `pubspec.lock` without separate dependency review. Failure in any step blocks the milestone and should be investigated from the exact error log. Passing this source-only suite will NOT satisfy the device-security acceptance gate.
