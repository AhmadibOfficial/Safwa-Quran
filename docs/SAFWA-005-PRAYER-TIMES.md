# SAFWA-005: Offline Prayer Times — separate feature draft

## Included in first engineering slice

- Five obligatory daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha)
  plus Sunrise as a non-prayer reference; a next-prayer indicator.
- Astronomical calculation using adhan_dart 2.0.1 (MIT), not a paid or
  network API.
- Manual city selection: Kaduna, Abuja, Kano, Lagos, Makkah, Doha, London.
  Never infer a user's precise location; no GPS, runtime permission or
  device tracking is enabled.
- City-specific IANA timezones, including daylight saving time.
- Optional calculation settings: MWL, Egyptian, Karachi, Umm al-Qura,
  ISNA and two Asr schools (standard and Hanafi).
- Settings saved locally using the existing shared_preferences package,
  plus manual Refresh, with transparent estimate disclaimers.
- This feature is independent of Quran text, its pending scholarly review,
  and the blocked production release.

## Library and provenance

- https://pub.dev/packages/adhan_dart version ^2.0.1, MIT license.
  Preserve license and attribution at distribution.
- https://pub.dev/packages/timezone version ^0.11.2.
  Full timezone database initialized locally.
- The timezone package requires modern Dart (>=3.10.0); pubspec has been
  updated to match. Confirm that the local installed Flutter SDK provides
  compatible Dart before installing new dependencies.
- The city coordinates are approximate city centers, not an assertion of
  exact user position. They do not replace a mosque's timetable.

## Local validation (new code has NOT passed Flutter tests yet)

```bash
git fetch origin
git checkout feature/safwa-005-prayer-times
flutter --version
flutter pub get
dart format lib/main.dart lib/prayer_times.dart test/prayer_times_test.dart
flutter analyze
flutter test
python3 scripts/quran_pipeline.py check
git status --short
```

No app store release, Firebase, paid services or permissions are requested.

## Before prayer-times production activation

Compare output against known published local mosque schedules for sample
dates, including winter/summer and locations at high latitude. Confirm
method rules and suitable user guidance/adjustments. Offer explicit city
search/custom coordinates and manual mosque adjustments after basic QA.
Add opt-in prayer reminders and licensed Adhan audio only in a later step.
Prayer calculation is not religious certification.

## Critical separate Quran gate

This feature branch is based on `feature/safwa-003-offline-mushaf`
and deliberately not on the stacked SAFWA-004 scholarly dossier.
`assets/data/content_activation.json`, `config/release_policy.json` and
all Quran original/approved sources remain unchanged. Quran reader activation
and all public releases stay BLOCKED pending two independent qualified reviews.
