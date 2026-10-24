# SAFWA-014 — Backup/restore recovery and independent review dossier

Status: **DRAFT / SOURCE-ONLY UNVALIDATED** (2026-10-24). This document is not a certificate or a security approval.

## Scope and baseline

- Stack: SharedPreferences allowlisted local settings; optional encrypted clipboard export using Argon2id-derived AES-256-GCM.
- Inherited Kali baseline at SAFWA-013: 59 Flutter tests and 11 Quran integrity tests passed; analyzer clean; source-only gate passed. **Those results predate the SAFWA-014 changes.**
- SAFWA-014 introduces a plaintext, reserved, non-exportable, on-device undo journal (`safwa_restore_recovery_v1`), attempts replay before launching the app, fails closed on corrupted journal, and adds deterministic simulated-interruption tests.
- Quran verified text, source manifest, scholarly authorization, Adhkar, recitation, notifications and public release remain untouched and locked.

## Guarantee boundary — read before use

**Do not advertise this as atomic, power-loss safe, or fully crash-proof.** The journal and preferences are written using SharedPreferences. Neither cross-key atomicity nor synchronous durability/fsync is established. A power cut may lose a journal write even when the API previously returned success. An OS process may stop between keys. Another isolate or plugin could race local data changes. A simulated exception is not evidence of hardware crash safety.

This recovery strategy attempts to restore the **pre-restore** snapshot when a journal exists at startup. If the journal is corrupt, typed incorrectly, or cannot be replayed, initialization displays a recovery-blocked screen. It does **not** silently delete the journal or reset personal data. This is an interim mitigation until a storage backend with verified transactional durability and recovery semantics can be deployed.

The journal duplicates private Salah records and other preference values **in plaintext** inside app storage. Existing SharedPreferences values are also plaintext. No claim of secure local encryption-at-rest is made. Keep the original encrypted backup separately in user-controlled secure storage. A passphrase cannot be recovered if forgotten. Clipboard contents remain outside the app's control and may persist in OS history or cross-device sync.

## Test plan and expected evidence

| Gate | Method | Pass condition | Current evidence |
|---|---|---|---|
| G1 | Simulate interruption after removing a recognized key | Restart recovery returns exact pre-restore settings; unrelated keys survive; recovery journal is removed | Test source added; execution pending |
| G2 | Simulate interruption after writing a replacement key | Previous data returns upon replay; repeated replay is a no-op | Test source added; execution pending |
| G3 | Inject handled storage write failure | Rollback occurs without silently losing prior data | Test source added; execution pending |
| G4 | Corrupt recovery journal | Recovery fails closed, leaves journal intact and blocks new export | Test source added; execution pending |
| G5 | Overlap restore calls | Second restore rejected; first eventually finishes | Test source added; execution pending |
| G6 | Tamper ciphertext/salt/nonce/tag; wrong passphrase | Authentication fails without writes | Test source added; execution pending |
| G7 | Alter KDF/version/format and invalid lengths | Reject before expensive KDF when possible; no writes | Test source added; execution pending |
| G8 | Export twice with same password and data | New random salts and nonces, distinct ciphertext | Test source added; execution pending |
| G9 | Nonexistent ayah refs | Strict per-Surah bounds reject 1:8, 114:7; accept 2:286 | Test source added; execution pending |
| G10 | Real cold-stop/power-loss and low-disk device tests | Recover **complete** old or new state with no data loss | **Not tested; cannot be guaranteed on current backend** |
| G11 | External AppSec/crypto and privacy/accessibility reviews | Verifiable independent reviewer sign-offs on exact commit SHA | **Not obtained** |

## Security review questions

1. Is Argon2id memory/cost appropriate across supported devices? Measure time, memory pressure, and denial-of-service exposure before approval.
2. Are AES-GCM nonce and salt generation, associated-data format, key lifecycle, and errors implemented correctly? Test library behaviour on real devices.
3. Can modified, oversized, malformed, or duplicated JSON structure trigger parser ambiguity, excessive work, unwanted writes, or leaks?
4. Is the restore confirmation tied to the **exact** inspected ciphertext and passphrase? Can input changes or parallel taps bypass review?
5. Can app-kill, OS reclaim, device restart, or low storage leave the journal partially written and unrecoverable? What durable engine replaces SharedPreferences?
6. Are saved Salah records, accessibility semantics, Arabic/RTL expectations, and privacy warnings acceptable in English, Hausa and Arabic?
7. Can plaintext backup legacy UI still be opened or reached unexpectedly? Review route isolation and clipboard behaviour.
8. Are app data, backup content and recovery journal excluded from analytics/crash reports and accessible only to the app sandbox?

## External review sign-off — currently EMPTY

**Independent AppSec/cryptography reviewer**
- Reviewer identity and professional qualification: PENDING
- Scope and exact commit SHA reviewed: PENDING
- Threat model / findings / severity / remediation: PENDING
- Signed approval or blocking decision with date: PENDING

**Independent privacy/accessibility reviewer**
- Reviewer identity and professional qualification: PENDING
- Scope and exact commit SHA reviewed: PENDING
- User testing, keyboard, screen-reader, local language/RTL and disclosure findings: PENDING
- Signed approval or blocking decision with date: PENDING

**No self-review by an assistant or repository owner can substitute for these reviews.** Reviewers must be genuinely independent; do not fabricate identities, approvals, scores, certificates, or evidence. Avoid sending real personal Salah records or user passphrases to anyone.

## Kali source-only validation (safe and reversible)

```bash
cd ~/Safwa-Quran || exit 1
git status --short --branch
git fetch origin
# Switch ONLY if git says it can preserve existing local changes.
git switch --track origin/feature/safwa-014-restore-recovery-security
flutter pub get --offline
flutter analyze
flutter test --reporter expanded
bash scripts/verify_source_only.sh --offline
git diff --check
git status --short --branch
```

If the switch is refused, **stop and inspect** rather than cleaning/resetting. Preserve modified `test/prayer_times_test.dart`, existing `android/`, `ios/`, `pubspec.lock`, and any stashes. No Gradle, emulator, native build, service deployment, permission changes, release, merge or file cleanup are permitted by this milestone.

## Exit criteria

- Verified source-only tests on Kali using the SAFWA-014 commit, including fresh fault-injection logs.
- Documented safe storage architecture with demonstrated durability and device-level recovery for the supported Android and iOS versions, not just mocked SharedPreferences.
- Privacy and security findings resolved and retested.
- Two actual independent review records for AppSec/cryptography and privacy/accessibility.
- Explicit owner authorization for dependency-ordered merging; separate Quran text and public-release approvals remain mandatory (independent qualified Hafs scholarly approvals still 0/2).
