# SAFWA-009 — Offline Seven-Day Prayer Planner

## What this delivers

Adds a new **7-Day Prayer Planner** route in the Companion hub without
requiring an Android emulator, GPS, network connection, user account,
notification permission, or paid API.

- Reads the existing explicitly chosen city; users must select a city
  if no valid saved value exists. Supports Kaduna, Abuja, Kano, Lagos,
  Makkah, Doha, and London.
- Reuses the existing offline `PrayerTimeService`, selected calculation
  method, and Standard/Hanafi Asr rule. The week view shares those
  preferences with the daily Prayer Times screen through local storage.
- Shows seven consecutive local **civil dates** with Fajr, Sunrise, Dhuhr,
  Asr, Maghrib, and Isha. Sunrise is clearly marked as a non-obligatory
  reference event. Provides previous/next week controls.
- Provides user-initiated **Copy 7 days**, generating text with city,
  time zone, method, Asr preference and a warning that the results are
  astronomical estimates. Clipboard is local and contains no accounts,
  Salah-journal entries, Quran text or device coordinates.
- Provides no OS notification/alarm, no Adhan and no religiously
  certified prayer times.

The planner uses 12:00 UTC as a date probe for the **currently listed
seven cities**. This is intentionally narrow: their timezone offsets
mean UTC noon maps to the same local date. The service checks that every
returned city calendar date matches the requested Gregorian date and
fails closed if that assumption ever becomes false. Expanding to
countries with UTC offsets outside this subset will require a
reworked city-date conversion approach before adding those cities.

No unsourced Quran, tafsir, Hadith or supplications are distributed.

## New files

- `lib/prayer_week.dart` — deterministic seven-day service, text
  copy format and Material UI route.
- `test/prayer_week_test.dart` — 8 tests for seven-day rollover,
  daily-versus-weekly equivalence, London DST transition, invalid
  date/coordinates, source-safe text copy, no default location,
  existing-city preferences and hub navigation.
- `lib/prayer_times.dart` strengthens coordinate validation to
  reject non-finite values.
- `lib/companion_features.dart` adds the navigation entry.
- `config/feature_status.json` registers this as draft pending
  execution on Kali.

## Validation — no emulator necessary

A guarded source-only check is available:

```bash
bash scripts/verify_source_only.sh
# Or, if Flutter/Dart packages are already cached:
bash scripts/verify_source_only.sh --offline
```

It runs the Python Quran integrity unit tests and fail-closed release check,
Flutter dependency resolution, static analysis, all Flutter unit/widget tests,
and Git diff whitespace check. It **does not** start an emulator, invoke Gradle,
compile an APK, reset Git or delete native/project files.

The patch is created through the connected repository tooling. It has
**not** been executed in a Flutter/Dart SDK by the assistant and is
**not** a claim that new tests pass or an Android APK was rebuilt.

Run in the developer's existing Kali checkout:

```bash
cd ~/Safwa-Quran
git status --short --branch
git fetch origin
git switch --track origin/feature/safwa-009-offline-weekly-prayer-planner

flutter pub get
dart format lib/prayer_week.dart lib/companion_features.dart \
  lib/prayer_times.dart test/prayer_week_test.dart
flutter analyze
flutter test
python3 scripts/quran_pipeline.py check
```

Keep `android/`, `ios/`, `pubspec.lock`, preexisting formatted
`test/prayer_times_test.dart` changes and previous stash safe. If
switching branches is blocked, **do not reset, clean, or pop the stash**;
inspect the exact conflict and preserve local files.

No emulator, Android run, gradle downloads, production build, automated
notification permissions or deployment is part of this stage.
The unrelated Kali Android build remains blocked until Gradle artifact
downloads fully complete and the debug APK is rebuilt successfully.

## Outstanding independent acceptance gates

1. Flutter analyzer and all tests pass on Kali after the new changes.
2. Compare times for several actual local-city dates/methods against
   a trusted published timetable and document any expected differences.
3. Verify the dated calendar view's usability and accessibility on a
   device when device testing becomes available.
4. Android/iOS platform files and pubspec.lock require careful
   native-source review before committing. Do not publish the APK.
5. Quran content approval still requires authentic, independent
   qualified Hafs scholarly review **2/2**. Current status **0/2**.
   `quran_reader_enabled=false`, `public_release_enabled=false`.
