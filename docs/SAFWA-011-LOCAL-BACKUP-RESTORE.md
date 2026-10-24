# SAFWA-011 — Local Safwa Backup & Restore (DRAFT)

## Scope

User-initiated, **offline and unencrypted** backup and restore of Safwa-owned
**local preferences only**, including optional Salah journal markers,
bookmarks, reading progress, prayer settings, learning progress and Tasbih.

The Privacy & Data screen links to Local Backup & Restore. No network,
background backup, camera, GPS, account, import-file permission, new dependency
or Android emulator is required.

## Design and safety rules

1. **Export:** Button opens a warning before it copies JSON to the **system
   clipboard**. The clipboard can leak to other software, keyboard managers or
   cross-device clipboard sync. This is an initial portable transfer method,
   **not secure encrypted backup storage**. Users are told to keep copies
   privately and never paste them into public chats.
2. **Format:** Versioned `safwa-local-preferences` JSON, `schema: 1`,
   recognized values and `checksum_sha256` over deterministic canonical
   JSON. SHA-256 catches accidental/obvious changes but **does not encrypt,
   authenticate ownership or prevent malicious re-hashing**.
3. **Inspection before mutation:** Reject JSON outside the supported size,
   unsupported schema, extra fields, unknown keys, type mismatches, malformed
   journal dates, invalid bookmark references, non-finite font values,
   duplicate markers and checksum mismatch. Do not silently auto-correct
   untrusted backup data.
4. **Restore:** Explicit user action to preview the backup counts, then a
   second confirmation before replacing Safwa's recognized preference keys.
   Existing recognized values absent in the backup are removed. Values
   belonging to unrelated apps or unknown future keys are untouched.
   A failed per-key operation attempts rollback from the local pre-restore
   snapshot, but the underlying SharedPreferences platform writes are not
   transactional. **A rollback is best-effort, not atomic or guaranteed.**
5. **Excluded:** Quran verses/corpus, source manifest, release policy, reviewer
   approvals, signing credentials, app secrets and arbitrary unknown data.
   No backup can enable the verified Quran reader or public release.
6. **Data lifecycle:** The app does not retain exported JSON internally after
   copying. On successful restore it clears the import field. A pasted JSON
   may still have been retained by the platform clipboard or keyboard, and
   current app screens may need reopening to reread preferences.
7. **Privacy:** Restoring local Salah entries is not a claim they were
   observed, verified, or that missing entries imply missed prayers.
   This tool is not production ready without encryption/protected native
   document picker, external security review, device tests and privacy policy.

## Files added or modified

- `lib/local_backup.dart` — versioned allowlisted export, strict schema
  parsing, SHA-256 checksum, explicit-consent restore and best-effort rollback.
- `lib/local_backup_page.dart` — UI warnings, manual clipboard export,
  paste/inspect, preview, replacement confirmation.
- `lib/companion_features.dart` — link from Privacy & Data.
- `test/local_backup_test.dart` — 9 unit/widget tests for allowlists,
  journal entry counts, round-trips, rejection, privacy and permissions.
- `config/feature_status.json` — mark SAFWA-010 source-only Kali gate
  passed, SAFWA-011 source implemented **pending Kali validation**.

## Run on Kali without emulator, APK or Gradle

```bash
cd ~/Safwa-Quran
git status --short --branch
git fetch origin
git switch --track origin/feature/safwa-011-local-backup-restore
bash scripts/verify_source_only.sh --offline
git status --short --branch
```

If the branch already exists use `git switch feature/safwa-011-local-backup-restore`
and `git pull --ff-only`; do not force overwrite anything. Preserve existing
untracked `android/`, `ios/`, `pubspec.lock`, local formatted
`test/prayer_times_test.dart` and saved Git stash. No `git clean`,
`git reset --hard`, `flutter clean` or cache deletions.

SAFWA-010 parent: **11/11 Python integrity tests**, **35/35 Flutter tests**,
`flutter analyze` clear, source-only gate PASS as shown by owner on Kali
on 2026-10-24. These results do not yet prove the new SAFWA-011 code passes.

Quran reader remains **OFF**; public release remains **OFF**; genuine
independent credentialed Hafs scholar authentications remain **0/2**.
No merge, no deployment and no scholarly endorsement are implied.
