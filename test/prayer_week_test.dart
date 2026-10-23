import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/companion_features.dart';
import 'package:safwa_quran/prayer_times.dart';
import 'package:safwa_quran/prayer_week.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final planner = PrayerWeekPlanner();
  final kaduna = prayerCities.firstWhere((city) => city.id == 'kaduna');

  test('seven ordered civil days cross a year without skipping dates', () {
    final week = planner.build(
      city: kaduna,
      start: DateTime.utc(2026, 12, 29),
      method: PrayerMethod.mwl,
      asr: AsrRule.standard,
    );
    expect(week.length, 7);
    expect(week.first.date.year, 2026);
    expect(week.first.date.month, 12);
    expect(week.first.date.day, 29);
    expect(week.last.date.year, 2027);
    expect(week.last.date.month, 1);
    expect(week.last.date.day, 4);
    expect(week.every((day) => day.events.length == 6), isTrue);
    expect(
      week.every((day) =>
          day.events.where((event) => event.isObligatory).length == 5),
      isTrue,
    );
    expect(
      week.every((day) =>
          !day.events.firstWhere((event) => event.name == 'Sunrise')
              .isObligatory),
      isTrue,
    );
  });

  test('weekly calculations agree with daily prayer calculator', () {
    final start = DateTime.utc(2026, 10, 23);
    final week = planner.build(
      city: kaduna, start: start, method: PrayerMethod.egyptian,
      asr: AsrRule.hanafi,
    );
    final today = PrayerTimeService().forInstant(
      kaduna, DateTime.utc(2026, 10, 23, 12),
      PrayerMethod.egyptian, AsrRule.hanafi,
    );
    expect(
      week.first.events.map((event) => event.at).toList(),
      today.events.map((event) => event.at).toList(),
    );
    expect(
      planner.build(
        city: kaduna, start: start, method: PrayerMethod.egyptian,
        asr: AsrRule.hanafi,
      ).first.events.first.at,
      week.first.events.first.at,
    );
  });

  test('London daylight saving switches during a seven-day window', () {
    final london = prayerCities.firstWhere((city) => city.id == 'london');
    final week = planner.build(
      city: london, start: DateTime.utc(2026, 3, 27),
      method: PrayerMethod.mwl, asr: AsrRule.standard,
    );
    expect(week[0].date.timeZoneOffset, Duration.zero);
    expect(week[3].date.timeZoneOffset, const Duration(hours: 1));
    expect(week[6].date.timeZoneOffset, const Duration(hours: 1));
  });

  test('invalid years and invalid coordinates are rejected', () {
    expect(
      () => planner.build(
        city: kaduna, start: DateTime.utc(1899, 12, 31),
        method: PrayerMethod.mwl, asr: AsrRule.standard,
      ),
      throwsFormatException,
    );
    const bad = PrayerCity('invalid', 'Invalid', 100, 0, 'Africa/Lagos');
    expect(
      () => planner.build(
        city: bad, start: DateTime.utc(2026, 10, 23),
        method: PrayerMethod.mwl, asr: AsrRule.standard,
      ),
      throwsFormatException,
    );
    const nonfinite = PrayerCity(
      'invalid_nan', 'Invalid NaN', double.nan, 0, 'Africa/Lagos',
    );
    expect(
      () => planner.build(
        city: nonfinite, start: DateTime.utc(2026, 10, 23),
        method: PrayerMethod.mwl, asr: AsrRule.standard,
      ),
      throwsFormatException,
    );
  });

  test('copied week discloses estimation, zone, method and sunrise', () {
    final week = planner.build(
      city: kaduna, start: DateTime.utc(2026, 10, 23),
      method: PrayerMethod.mwl, asr: AsrRule.standard,
    );
    final text = planner.readableCopy(
      city: kaduna, method: PrayerMethod.mwl,
      asr: AsrRule.standard, schedules: week,
    );
    expect(text, contains('Kaduna'));
    expect(text, contains('Africa/Lagos'));
    expect(text, contains('Astronomical estimates'));
    expect(text, contains('Sunrise is not obligatory'));
    expect(text, contains('2026-10-23'));
    expect(text, contains('2026-10-29'));
    expect(text, contains('Fajr:'));
    expect(
      () => planner.readableCopy(
        city: kaduna, method: PrayerMethod.mwl,
        asr: AsrRule.standard, schedules: week.take(3).toList(),
      ),
      throwsFormatException,
    );
  });

  testWidgets('weekly planner does not assume a city or device location',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrayerWeekPage()));
    await tester.pumpAndSettle();
    expect(find.text('7-Day Prayer Planner'), findsOneWidget);
    expect(
      find.text('Select a city to see a seven-day schedule.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('copy_week')), findsNothing);
  });

  testWidgets('weekly planner renders a schedule from saved local city',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_prayer_method': 'mwl',
      'safwa_prayer_asr': 'standard',
    });
    await tester.pumpWidget(const MaterialApp(home: PrayerWeekPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copy_week')), findsOneWidget);
    expect(find.text('7-Day Prayer Planner'), findsOneWidget);
  });

  testWidgets('companion hub exposes the weekly planning route',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompanionHub())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7-Day Prayer Planner'));
    await tester.pumpAndSettle();
    expect(find.text('Plan your Salah week'), findsOneWidget);
  });
}
