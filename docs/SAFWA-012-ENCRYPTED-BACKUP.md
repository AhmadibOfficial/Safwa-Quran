# SAFWA-012 — Encrypted Backup & Accessible Restore (source-only DRAFT)

## Purpose

Build a safer opt-in alternative to the SAFWA-011 *unencrypted*
clipboard backup. **Safwa's Privacy & Data screen opens the new
Protected Local Backup route**. The older plaintext backup class and
tests remain in the repository for compatibility review but are no
longer the primary navigation path. Do not advertise production-grade
backup until crypto/device/privacy security review.

## Actual implementation

- Uses published Dart package cryptography ^2.9.0:
  - Argon2id password derivation: memory **19456 KiB (~19 MiB)**,
    iterations **2**, parallelism **1**, output **32 bytes**.
  - AES-256-GCM authenticated encryption, 12-byte random nonce and
    16-byte authentication tag; explicit fixed associated data.
  - Fresh 16-byte salt from Dart's cryptographically secure random
    number generator for every export.
- A **fixed versioned envelope** includes format, version, fixed KDF
  label, salt, nonce, ciphertext, and tag. Import requires exact known
  schema and size bounds; untrusted text cannot set KDF cost parameters.
- Passphrases of at least 16 characters are required for *new* exports.
  Password fields are obscured, autocorrect and suggestions are off,
  and confirmation is required to export. Weak-but-long passphrases
  are still vulnerable to offline guesses.
- User explicitly confirms copying encrypted ciphertext onto the system
  clipboard. Clipboard history, sync and other apps can still access
  the encrypted data and its metadata. Passphrase is **never copied**.
- Import is inspect-first: decrypt with passphrase, authenticate GCM
  tag and validate the inner SAFWA-011 allowlist/checksum before showing
  non-sensitive counts. Restoration requires a separate modal
  confirmation and re-decryption of the unchanged import.
- Input status text is in a screen-reader **live region**; forms have
  normal visible labels. Restore is hidden until a successful preview.
- No file picker, cloud sync, background jobs, GPS, notifications,
  account, Android emulator, Gradle, or APK building is used here.

## Privacy and tradeoffs

- This feature reduces **plaintext exposure in copied backups** but
  cannot secure a compromised device, memory, the OS clipboard, app
  backups, weak passwords, or someone who learns the passphrase.
- Loss of passphrase makes the backup unrecoverable. A password alone
  is not linked to an account or identity; authenticated encryption
  proves only that ciphertext matches the derived secret key.
- Encryption/authentication do not make **restore transactional**.
  Restoration still uses SharedPreferences and only best-effort
  rollback on failures. The original encrypted backup should be kept.
- Existing plaintext SAFWA-011 implementation is left in source (for
  compatibility) but is no longer linked from Privacy & Data. Avoid
  using old plaintext clipboard exports for sensitive journal data.
- Only Safwa-owned personal app preferences are backed up. Never
  export Quran verses, provenance/approval flags, reviewer identities,
  API keys, store credentials or signing secrets.
- Crypto implementation, dependency provenance, mobile performance,
  passphrase strength, backup ergonomics and assistive-technology
  behavior require independent audit and actual device testing before
  public release.

## Files

- New: lib/encrypted_backup.dart, lib/secure_backup_page.dart,
  test/encrypted_backup_test.dart
- Modified: lib/companion_features.dart, pubspec.yaml,
  config/feature_status.json
- New cryptography dependency requires an **online** package resolution
  once. Future source-only checks may then run offline.

## Kali acceptance (no emulator)

```bash
cd ~/Safwa-Quran
git status --short --branch
git fetch origin
git switch --track origin/feature/safwa-012-encrypted-backup-accessibility
flutter pub get
bash -n scripts/verify_source_only.sh
bash scripts/verify_source_only.sh --offline
git status --short --branch
```

If the new branch already exists, switch to it directly and use
git pull --ff-only. Do not reset/clean/stash-pop. Keep the user's local
test/prayer_times_test.dart modification, untracked android/, ios/,
pubspec.lock, and existing Git stash untouched. No Flutter upgrade
or Gradle cache cleanup.

**Verified parent SAFWA-011:** 11 Python integrity tests, 44 Flutter
unit/widget tests, flutter analyze and complete source-only gate PASSED
on Kali on 2026-10-24. New SAFWA-012 code is not yet Kali tested.

**Release safeguards unchanged:** Quran reader OFF, public release
OFF, independently authenticated qualified Hafs scholars 0/2.
All source/religious content remains locked; new PR is draft.
