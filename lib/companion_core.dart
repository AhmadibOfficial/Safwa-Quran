import 'dart:math' as math;
import 'safwa_preferences.dart';

/// Great-circle bearing clockwise from true north. Not a live magnetometer.
double qiblaBearing(double latitude, double longitude) {
  if (!latitude.isFinite || !longitude.isFinite ||
      latitude.abs() > 90 || longitude.abs() > 180) {
    throw const FormatException('Invalid manual location coordinates');
  }
  const kaabaLat = 21.4225;
  const kaabaLon = 39.8262;
  final p1 = latitude * math.pi / 180;
  final p2 = kaabaLat * math.pi / 180;
  final delta = (kaabaLon - longitude) * math.pi / 180;
  final y = math.sin(delta) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) -
      math.sin(p1) * math.cos(p2) * math.cos(delta);
  if (x.abs() < 1e-12 && y.abs() < 1e-12) {
    throw const FormatException('Qibla undefined at this coordinate');
  }
  return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360;
}

String civilDateKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

const salahNames = <String>['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

/// User-directed entries only. Data saved on device, never synced.
class LocalSalahJournal {
  const LocalSalahJournal();
  String _key(DateTime date) => 'safwa_salah_${civilDateKey(date)}';

  Future<Set<String>> read(DateTime date) async {
    final prefs = await SafwaPreferences.getInstance();
    return (prefs.getStringList(_key(date)) ?? <String>[])
        .where(salahNames.contains).toSet();
  }

  Future<Set<String>> toggle(DateTime date, String prayer) async {
    if (!salahNames.contains(prayer)) {
      throw const FormatException('Unknown prayer name');
    }
    final prefs = await SafwaPreferences.getInstance();
    final entries = await read(date);
    if (!entries.add(prayer)) entries.remove(prayer);
    final ordered = salahNames.where(entries.contains).toList();
    if (!await prefs.setStringList(_key(date), ordered)) {
      throw StateError('Could not save the journal');
    }
    return entries;
  }

  Future<void> clearDay(DateTime date) async {
    final prefs = await SafwaPreferences.getInstance();
    if (!await prefs.remove(_key(date))) {
      throw StateError('Could not clear the journal');
    }
  }
}

class LocalTasbih {
  const LocalTasbih();
  static const countKey = 'safwa_tasbih_count';
  static const targetKey = 'safwa_tasbih_goal';

  Future<int> count() async =>
      (await SafwaPreferences.getInstance()).getInt(countKey) ?? 0;
  Future<int> goal() async =>
      (await SafwaPreferences.getInstance()).getInt(targetKey) ?? 33;

  Future<int> increment() async {
    final prefs = await SafwaPreferences.getInstance();
    final old = prefs.getInt(countKey) ?? 0;
    if (old < 0 || old >= 999999) {
      throw StateError('Counter at maximum; reset to continue.');
    }
    if (!await prefs.setInt(countKey, old + 1)) {
      throw StateError('Could not save counter');
    }
    return old + 1;
  }

  Future<void> setGoal(int goal) async {
    if (goal <= 0 || goal > 1000000) {
      throw const FormatException('Goal outside supported range');
    }
    final prefs = await SafwaPreferences.getInstance();
    if (!await prefs.setInt(targetKey, goal)) {
      throw StateError('Could not save goal');
    }
  }

  Future<void> reset() async {
    final prefs = await SafwaPreferences.getInstance();
    if (!await prefs.setInt(countKey, 0)) {
      throw StateError('Could not reset counter');
    }
  }
}

/// Tabular/civil Islamic calendar estimate, not crescent observation.
class EstimatedHijriDate {
  const EstimatedHijriDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;
  static const monthNames = <String>[
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
    'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Shaaban',
    'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah',
  ];
  String get label => '$day ${monthNames[month - 1]} $year AH (estimate)';
}

int _gregorianJdn(DateTime date) {
  final a = (14 - date.month) ~/ 12;
  final y = date.year + 4800 - a;
  final m = date.month + 12 * a - 3;
  return date.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 -
      y ~/ 100 + y ~/ 400 - 32045;
}

int _hijriStart(int year, int month) {
  final monthDays = (59 * (month - 1) + 1) ~/ 2;
  return 1 + monthDays + 354 * (year - 1) +
      (3 + 11 * year) ~/ 30 + 1948439 - 1;
}

EstimatedHijriDate approximateHijri(DateTime date, {int adjustmentDays = 0}) {
  if (date.year < 1900 || date.year > 2200 || adjustmentDays.abs() > 2) {
    throw const FormatException('Unsupported calendar date or adjustment');
  }
  final jd = _gregorianJdn(date) + adjustmentDays;
  var year = (30 * (jd - 1948439) + 10646) ~/ 10631;
  if (year < 1) year = 1;
  while (_hijriStart(year + 1, 1) <= jd) { year++; }
  while (_hijriStart(year, 1) > jd) { year--; }
  var month = 1;
  while (month < 12 && _hijriStart(year, month + 1) <= jd) {
    month++;
  }
  final day = jd - _hijriStart(year, month) + 1;
  if (day < 1 || day > 30) {
    throw StateError('Calendar approximation failed');
  }
  return EstimatedHijriDate(year, month, day);
}

/// Local preference ONLY; no Android/iOS notification scheduled.
class PrayerReminderPreferences {
  const PrayerReminderPreferences();
  static String key(String prayer) => 'safwa_remind_$prayer';

  Future<bool> enabled(String prayer) async {
    if (!salahNames.contains(prayer)) return false;
    return (await SafwaPreferences.getInstance()).getBool(key(prayer)) ?? false;
  }

  Future<void> save(String prayer, bool enabled) async {
    if (!salahNames.contains(prayer)) {
      throw const FormatException('Invalid prayer name');
    }
    final prefs = await SafwaPreferences.getInstance();
    if (!await prefs.setBool(key(prayer), enabled)) {
      throw StateError('Could not save reminder preference');
    }
  }
}

/// Deletes Safwa-owned local preferences; does not touch unrelated apps.
Future<int> clearSafwaLocalData() async {
  final prefs = await SafwaPreferences.getInstance();
  if (prefs.isSqliteCanonical) {
    // One SQLite transaction, not multiple per-key operations. Legacy
    // source data is NOT erased as a side-effect of SQL privacy deletion.
    return prefs.clearCanonicalData();
  }
  final keys = prefs.getKeys().where((key) =>
      key.startsWith('safwa_') ||
      <String>{'saved_surahs','saved_ayat','last_read','arabic_font_size'}
          .contains(key)).toList();
  for (final key in keys) {
    if (!await prefs.remove(key)) {
      throw StateError('Failed deleting $key');
    }
  }
  return keys.length;
}
