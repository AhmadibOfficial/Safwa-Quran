import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/prayer_times.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('five obligatory prayers and separate sunrise, deterministic', () {
    final calculator = PrayerTimeService();
    final city = prayerCities.first;
    final instant = DateTime.utc(2026, 10, 19, 11);
    final first = calculator.forInstant(
        city, instant, PrayerMethod.mwl, AsrRule.standard);
    final again = calculator.forInstant(
        city, instant, PrayerMethod.mwl, AsrRule.standard);
    expect(first.events.map((e) => e.name).toList(),
        ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    expect(first.events.where((e) => e.isObligatory).length, 5);
    expect(first.events.map((e) => e.at).toList(),
        again.events.map((e) => e.at).toList());
  });

  test('next day Fajr follows today's Isha', () {
    final calculator = PrayerTimeService();
    final city = prayerCities.first;
    final today = calculator.forInstant(
        city, DateTime.utc(2026, 10, 19, 11),
        PrayerMethod.egyptian, AsrRule.standard);
    final justAfterIsha =
        today.events.last.at.add(const Duration(minutes: 2));
    final next = calculator.nextPrayer(
        city, justAfterIsha, PrayerMethod.egyptian, AsrRule.standard);
    expect(next.name, 'Fajr');
    expect(next.at.isAfter(justAfterIsha), isTrue);
  });

  test('city timezone uses daylight saving in London', () {
    final calculator = PrayerTimeService();
    final london = prayerCities.firstWhere((c) => c.id == 'london');
    final winter = calculator.forInstant(
        london, DateTime.utc(2026, 1, 15, 12),
        PrayerMethod.mwl, AsrRule.standard);
    final summer = calculator.forInstant(
        london, DateTime.utc(2026, 7, 15, 12),
        PrayerMethod.mwl, AsrRule.standard);
    expect(winter.date.timeZoneOffset, Duration.zero);
    expect(summer.date.timeZoneOffset, const Duration(hours: 1));
  });

  test('city choice is manual and locations have valid coordinates', () {
    SharedPreferences.setMockInitialValues({});
    expect(prayerCities.map((c) => c.id).toSet().length,
        prayerCities.length);
    expect(prayerCities.every((c) =>
        c.latitude.abs() <= 90 && c.longitude.abs() <= 180), isTrue);
  });

  test('invalid coordinates fail rather than invent times', () {
    const invalid = PrayerCity(
        'invalid', 'Invalid', 94, 0, 'Africa/Lagos');
    expect(() => PrayerTimeService().forInstant(
        invalid, DateTime.utc(2026, 10, 19),
        PrayerMethod.mwl, AsrRule.standard), throwsFormatException);
  });
}
