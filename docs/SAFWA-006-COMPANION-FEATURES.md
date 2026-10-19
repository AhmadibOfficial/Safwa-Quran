# SAFWA-006 — Companion feature suite (source-first, draft only)

This branch is stacked on SAFWA-005 Prayer Times (PR #5). It is **not**
stacked on SAFWA-004 Quran source-review PR #4. No Quran Arabic assets, activation
flags, attestation files or release policies are changed.

## Functional local-development slices (not yet validated on Kali)

- **Prayer Times:** five daily prayers, sunrise, calculations, manual cities,
  choice of methods, IANA timezone support, next prayer (from SAFWA-005).
- **Qibla:** mathematical great-circle bearing clockwise from true north
  using manually selected city. No magnetometer or device GPS. Compass
  calibration and magnetic declination are not provided.
- **Salah Journal:** optional local checklist for each Gregorian day,
  reversible entries. An unmarked entry is NOT automatically classified
  as a missed prayer, and no data leaves the device via this feature.
- **Tasbih Counter:** persisted count, configurable personal goal 33/99,
  reset with confirmation, maximum count guard. The goals do not imply
  any specific religious ruling.
- **Islamic Calendar:** explicitly approximate tabular/civil date from
  local Gregorian day, with user-controlled ±2-day adjustment for
  sighting conventions. No false claims about Ramadan/Eid start dates.
- **Prayer Reminders:** local preference screen and saved per-prayer
  choices. **NO OPERATING-SYSTEM NOTIFICATIONS ARE SCHEDULED.**
- **Adhkar and Du'a:** review-gated empty library. No unsourced Arabic
  hadith, prophetic supplication, translated devotional text or
  permissions/rights fabricated.
- **Quran Recitation:** intentionally empty until reciter/audio rights,
  exact surah/ayah alignment and human QA are complete.
- **Learning:** personal study-topic planner and saved progress; no
  unreviewed Islamic lesson content or credential claims.
- **Languages:** saved English/Hausa/Arabic *preference*, not yet a
  translated user interface. No Quran translations activated.
- **Privacy:** confirmation-before-deletion of Safwa app local preferences
  including bookmarks/journal, without deleting unrelated app keys.

## Manual validation required before any merges

Dart/Flutter are not installed in the assistant's execution environment,
so code analysis, Flutter builds, widget tests, and device review HAVE NOT
yet been executed. To run on the user's Kali Flutter environment:

\`\`\`bash
cd ~/Safwa-Quran
git fetch origin
git switch --track origin/feature/safwa-006-companion-features
flutter --version
flutter pub get
dart format lib/main.dart lib/prayer_times.dart lib/companion_core.dart \
  lib/companion_features.dart test/companion_core_test.dart \
  test/companion_widget_test.dart test/prayer_times_test.dart
flutter analyze
flutter test
python3 scripts/quran_pipeline.py check
git status --short
\`\`\`

Resolve all failures before merging. Confirm prayer calculations against
an actual local mosque timetable; test device orientation / city choice,
DST and high-latitude cases, local data persistence, privacy deletion and
accessibility. A "feature implemented" code status is not a QA result.

## Future production gates / not claimed as delivered

- Prayer reminders: integrate per-platform local notification scheduling,
  permissions, cancellation, timezone/DST refresh and quiet hours.
- Qibla: implement a sensor compass only after sensor calibration,
  magnetic declination and real-device validation.
- Hijri: verify region-specific sighting/authority calendar before using
  Ramadan, Eid or fasting alerts.
- Adhkar, learning, translated Quran, recitation: secure rights-cleared
  reference content, independent qualified approval, translations and
  attribution; tests must protect immutable Arabic.
- Localization: proper English/Hausa/Arabic strings and RTL QA.
- Accessibility, device battery impact and data-loss recovery tests.

**PRODUCTION HOLD:** \`assets/data/content_activation.json\` remains reader
OFF, \`config/release_policy.json\` remains public release OFF, and
SAFWA-004's two independent genuine scholarly approvals are still 0/2.
Do not merge/deploy any of the stacked PRs automatically.
