import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/companion_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Qibla bearing has sane range and rejects invalid coordinates', () {
    final bearing = qiblaBearing(10.5105, 7.4165);
    expect(bearing, greaterThan(0));
    expect(bearing, lessThan(360));
    expect(() => qiblaBearing(120, 4), throwsFormatException);
    expect(() => qiblaBearing(double.nan, 4), throwsFormatException);
  });

  test('local Salah journal is explicit, consistent and reversible', () async {
    final today = DateTime(2026, 10, 19);
    const journal = LocalSalahJournal();
    expect(await journal.read(today), isEmpty);
    expect(await journal.toggle(today, 'Fajr'), {'Fajr'});
    expect(await journal.toggle(today, 'Dhuhr'), {'Fajr', 'Dhuhr'});
    expect(await journal.toggle(today, 'Fajr'), {'Dhuhr'});
    expect(await journal.read(today), {'Dhuhr'});
    await journal.clearDay(today);
    expect(await journal.read(today), isEmpty);
    await expectLater(journal.toggle(today, 'Sunrise'), throwsFormatException);
  });

  test('Tasbih counter persists, checks goals and can reset', () async {
    const counter = LocalTasbih();
    expect(await counter.count(), 0);
    expect(await counter.goal(), 33);
    expect(await counter.increment(), 1);
    expect(await counter.count(), 1);
    await counter.setGoal(99);
    expect(await counter.goal(), 99);
    await expectLater(counter.setGoal(0), throwsFormatException);
    await counter.reset();
    expect(await counter.count(), 0);
  });

  test('approximate Hijri stays bounded and adjusts from local convention', () {
    final today = DateTime(2026, 10, 19);
    final normal = approximateHijri(today);
    final shifted = approximateHijri(today, adjustmentDays: 1);
    expect(normal.year, greaterThan(1400));
    expect(normal.month, inInclusiveRange(1, 12));
    expect(normal.day, inInclusiveRange(1, 30));
    expect(shifted.month, inInclusiveRange(1, 12));
    expect(shifted.day, inInclusiveRange(1, 30));
    expect(normal.label, contains('(estimate)'));
    expect(() => approximateHijri(today, adjustmentDays: 3),
        throwsFormatException);
  });

  test('reminder preference is stored but does not schedule OS alerts', () async {
    const prefs = PrayerReminderPreferences();
    expect(await prefs.enabled('Fajr'), isFalse);
    await prefs.save('Fajr', true);
    expect(await prefs.enabled('Fajr'), isTrue);
    expect(await prefs.enabled('Sunrise'), isFalse);
    await expectLater(prefs.save('Sunrise', true), throwsFormatException);
  });

  test('privacy reset deletes only Safwa-owned keys', () async {
    SharedPreferences.setMockInitialValues({
      'safwa_tasbih_count': 4,
      'saved_ayat': ['1:1'],
      'unrelated_app_key': 'preserve',
    });
    final removed = await clearSafwaLocalData();
    final prefs = await SharedPreferences.getInstance();
    expect(removed, 2);
    expect(prefs.getInt('safwa_tasbih_count'), isNull);
    expect(prefs.getStringList('saved_ayat'), isNull);
    expect(prefs.getString('unrelated_app_key'), 'preserve');
  });

  test('date key uses stable local calendar representation', () {
    expect(civilDateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
