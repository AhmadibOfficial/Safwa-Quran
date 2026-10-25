# SAFWA-016 — Offline Quran Recitation (Source-only Foundation)

**Milestone status: SOURCE-IMPLEMENTED / KALI UNVERIFIED / PUBLIC PLAYBACK LOCKED.**
This feature is deliberately independent of SAFWA-015D's unfinished **physical Android/iOS device durability tests**. The previous, verified SAFWA-015D parent commit `13196ae5502a448f3fc5bdad9d22e7eb7f16455e` passed **117 Flutter**, **11 Quran Python integrity**, zero analyzer issues. Those results are NOT evidence for this branch.

## Proposed user experience

- Listen to **authentic recorded Quran recitation offline**, without cellular data or Wi-Fi during playback.
- A library organized by **reciter** and **Surah**, initially whole-Surah MP3; bookmarks/last played, ayah-level playback and background-audio controls are future scoped and not claimed.
- Optional fully downloaded content after verified permission and safe network/retention handling. No streaming fallback, no hidden tracking, no internet permission requirement for local playback.
- Source-aware Quran text must remain separate from audio approval. Text reader is BLOCKED until two independently qualified Hafs reviews; audio needs its own source/reciter, rights and content quality audit.

The user has not yet specified a reciter or recordings; **none are selected, acquired or bundled**. A recording merely being accessible online does **not** establish redistribution or download rights.

## Implemented in this draft

1. `assets/data/offline_recitation_manifest.json`: empty, `LOCKED` catalog with no recordings.
2. `lib/offline_recitation.dart`: typed provenance data for reciter, whole-Surah number/Ayah count, exact MP3 basename, bounded byte size and SHA-256, attribution, redistribution-rights evidence and two distinct review-evidence references. Manifest parses `LOCKED` or `REVIEW_ONLY` only; **no public `APPROVED` state**. Whole-Surah count is checked against a trusted 114-Surah/6236-Ayah catalog.
3. `LocalRecitationFileVerifier`: only accepts a real local review directory and exact filename (no URLs, traversal, symbolic-link final audio file). Streams SHA-256 and compares file length and stable stat metadata before returning a path. **Not proof of real Quran recitation or safe against all filesystem races**; run only in app-owned immutable review sandboxes. File-header/decoder/content verification remains a device review step.
4. `lib/offline_recitation_player.dart`: isolated `just_audio` adapter for authorized review sessions. Uses `setFilePath`, `play`, `pause`, `seek`, `stop` and `dispose`, **never `setUrl` or remote audio**. Accepts reviewed chapter-count metadata, an explicitly provided isolated directory and a caller's explicit review flag. This is NOT wired into `main.dart` or the visible page.
5. `lib/offline_recitation_page.dart`: accessible status screen, linked from the main Home page, which explicitly says recordings are not enabled. It does not instantiate a player even if a review-only manifest appears.
6. `scripts/check_offline_audio.py`: fail-closed check that the shipping manifest is **LOCKED and empty**, no audio files were introduced in `assets/` or `sources/`, no public app imports the review player, and Quran/release approval flags remain blocked. Runs inside `scripts/verify_source_only.sh --offline` and the GitHub religious-content-integrity workflow.
7. `test/offline_recitation_test.dart`: **14 new source-defined Flutter tests** (locked state, metadata rights/reviewer evidence, unsafe path/duplicate rejection, length/hash checks, chapter-count match/mismatch, missing or tampered file refusal, inaccessible audio UI). `scripts/tests/test_offline_recitation_gate.py`: **3 new Python checks** for the mandatory audio release lock.

**Acceptance targets, not results:** previous 117 Flutter + 14 = **131 Flutter tests**; previous 11 Quran Python + 3 = **14 Python tests**; zero analyzer issues. Tests have **not** run on the new SAFWA-016 branch or on physical Android/iOS devices.

## Why playback still cannot be enabled

- Audio rights: explicit grant for copying, offline storage, redistribution and use in the intended app, with source and license records, attribution and territory/expiration restrictions reviewed. No third-party recitation downloads or website scraping until legally reviewed.
- Audio content review: identify the reciter and riwayah (for example, Hafs 'an 'Asim where applicable), compare actual audible recitation to verified references, ensure consistent completeness for every Surah recording and two independent qualified audio-content reviewers. Manifest evidence strings alone **do not count** as human signoff.
- Security: verify all bytes before playing and at import; prevent wrong-file binding, symlink/path attacks, extraction traversal, downloader interception, stale hashes and temp-file swap. Avoid storing private playback behavior without user need or explicit choice.
- Offline acceptance: Android/iOS test sessions with **network disabled**, seek/pause/stop, app lifecycle, headphones/calls/audio focus, corruption, partial transfers, low-storage and restarted playback from app-private storage; device support must be verified, not inferred from plugin documentation.
- Media platform review: `just_audio` is a third-party player package. The adapter has no streaming source or locally enabled background/media-service feature. Android/iOS permissions and packaging must be reviewed in a **separate disposable app**; no production platform projects generated here.
- Quran source policy: Quran text reader and public release still **BLOCKED**; authenticated Hafs scholarly approvals **0/2**. Audio cannot be substituted for text-source authorization.
- SAFWA-015D physical device recovery, multi-isolate privacy-safe migration, legacy retention/erasure, independent AppSec/crypto/privacy/accessibility review remain a separate unfinished milestone.

## Non-destructive Kali source-only validation

Use a **new**, detached worktree; do not overwrite `~/Safwa-Quran`, its user-modified `test/prayer_times_test.dart`, existing `android/`, `ios/`, `pubspec.lock`, Git stashes or previous review worktrees. Work in a child Bash shell so `exit` cannot close the current interactive terminal.

```bash
bash <<'BASH'
set -Eeuo pipefail
trap 'r=$?; if [ "$r" -ne 0 ]; then
  echo "SAFWA-016 stopped with $r; terminal remains open."
fi' EXIT

cd "$HOME/Safwa-Quran"
git fetch origin
REVIEW="$HOME/Safwa-Quran-016-review"
EXPECTED="__REPLACE_WITH_VERIFIED_HEAD_SHA__"

test "$(git rev-parse origin/feature/safwa-016-offline-recitation-foundation)" = "$EXPECTED"
if [ -e "$REVIEW" ] || [ -L "$REVIEW" ]; then
  echo "STOP: SAFWA-016 worktree already exists."
  exit 1
fi
git worktree add --detach "$REVIEW" "$EXPECTED"
cd "$REVIEW"

flutter pub get
flutter analyze
python3 scripts/check_offline_audio.py
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/offline_recitation_test.dart
bash scripts/verify_source_only.sh --offline
git diff --check
git status --short --branch
git rev-parse HEAD
BASH
```

Before running, replace the documented SHA placeholder with the exact current PR head returned by GitHub. Source-only only: no Gradle/APK, emulator, native-device installation, audio download or filesystem cleanup. On failure preserve the full terminal output and do not claim passing tests. **Do not use `git clean`, `reset --hard`, or `flutter clean`.**

## Release decision

SAFWA-016 is an **unmerged draft source foundation**. Public recitation playback OFF; no approved files/rights, no actual offline Quran audio provided, release/text reader OFF. Physical device and independent reviews remain mandatory.
