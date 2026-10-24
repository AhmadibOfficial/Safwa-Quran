import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'companion_core.dart';
import 'companion_directory.dart';

/// A user-controlled, UNENCRYPTED export of local Safwa preferences only.
///
/// SHA-256 detects accidental/casual edits. It is NOT authentication,
/// encryption, or evidence that an imported document is trustworthy.
class SafwaBackupPreview {
  SafwaBackupPreview._(this._values, this.sha256);

  final Map<String, Object> _values;
  final String sha256;

  int get keyCount => _values.length;
  int get journalDays =>
      _values.keys.where((key) => key.startsWith('safwa_salah_')).length;
  int get savedSurahs =>
      (_values['saved_surahs'] as List<String>?)?.length ?? 0;
  int get savedAyat =>
      (_values['saved_ayat'] as List<String>?)?.length ?? 0;
}

class LocalSafwaBackup {
  const LocalSafwaBackup();

  static const int schema = 1;
  static const int maximumCharacters = 1000000;
  static const String format = 'safwa-local-preferences';

  static const Set<String> _otherKeys = {
    'saved_surahs',
    'saved_ayat',
    'last_read',
    'arabic_font_size',
    'safwa_prayer_city',
    'safwa_prayer_method',
    'safwa_prayer_asr',
    'safwa_tasbih_count',
    'safwa_tasbih_goal',
    'safwa_language',
    'safwa_learning_progress',
    'safwa_companion_pins',
  };

  static const Set<String> _cityIds = {
    'kaduna', 'abuja', 'kano', 'lagos', 'makkah', 'doha', 'london',
  };
  static const Set<String> _methods = {
    'mwl', 'egyptian', 'karachi', 'ummAlQura', 'isna',
  };
  static const Set<String> _asr = {'standard', 'hanafi'};
  static const Set<String> _languages = {'en', 'ha', 'ar'};
  static const Set<String> _topics = {
    'Arabic reading foundations',
    'Tajwid terminology',
    'Memorization planning',
    'Daily revision routine',
    'Finding reliable references',
    'Teacher-guided assessment',
  };

  static final RegExp _journalKey =
      RegExp(r'^safwa_salah_(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _ayahRef = RegExp(r'^([1-9]\d{0,2}):([1-9]\d{0,2})$');
  static final RegExp _surahRef = RegExp(r'^[1-9]\d{0,2}$');

  static bool _allowedKey(String key) {
    if (_otherKeys.contains(key)) return true;
    if (key.startsWith('safwa_remind_')) {
      return salahNames.contains(key.substring('safwa_remind_'.length));
    }
    final match = _journalKey.firstMatch(key);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year < 2000 || year > 2099 || month < 1 || month > 12 ||
        day < 1 || day > 31) {
      return false;
    }
    final civil = DateTime.utc(year, month, day);
    return civil.year == year && civil.month == month && civil.day == day;
  }

  static bool _validRef(String value) {
    final match = _ayahRef.firstMatch(value);
    if (match == null) return false;
    final chapter = int.parse(match.group(1)!);
    final ayah = int.parse(match.group(2)!);
    return chapter >= 1 && chapter <= 114 && ayah >= 1 && ayah <= 286;
  }

  static List<String> _validList(
    Object value,
    int limit,
    bool Function(String) allowed,
  ) {
    if (value is! List || value.length > limit ||
        value.any((item) => item is! String ||
            item.length > 90 || !allowed(item))) {
      throw const FormatException('Invalid Safwa preference list');
    }
    final result = List<String>.from(value);
    if (result.toSet().length != result.length) {
      throw const FormatException('Repeated Safwa preference value');
    }
    return List<String>.unmodifiable(result);
  }

  static Object _validatedValue(String key, Object value) {
    if (!_allowedKey(key)) {
      throw const FormatException('Unsupported Safwa backup key');
    }
    if (key.startsWith('safwa_salah_')) {
      return _validList(value, 5, salahNames.contains);
    }
    if (key.startsWith('safwa_remind_')) {
      if (value is bool) return value;
      throw const FormatException('Reminder preference must be boolean');
    }
    if (key == 'saved_surahs') {
      return _validList(value, 114, (s) =>
          _surahRef.hasMatch(s) && int.parse(s) <= 114);
    }
    if (key == 'saved_ayat') {
      return _validList(value, 6236, _validRef);
    }
    if (key == 'safwa_learning_progress') {
      return _validList(value, _topics.length, _topics.contains);
    }
    if (key == 'safwa_companion_pins') {
      return _validList(value, companionIds.length, companionIds.contains);
    }
    if (key == 'safwa_prayer_city' && value is String &&
        _cityIds.contains(value)) {
      return value;
    }
    if (key == 'safwa_prayer_method' && value is String &&
        _methods.contains(value)) {
      return value;
    }
    if (key == 'safwa_prayer_asr' && value is String &&
        _asr.contains(value)) {
      return value;
    }
    if (key == 'safwa_language' && value is String &&
        _languages.contains(value)) {
      return value;
    }
    if (key == 'last_read' && value is String && _validRef(value)) {
      return value;
    }
    if (key == 'arabic_font_size' && value is double &&
        value.isFinite && value >= 20 && value <= 48) {
      return value;
    }
    if (key == 'safwa_tasbih_count' && value is int &&
        value >= 0 && value <= 999999) {
      return value;
    }
    if (key == 'safwa_tasbih_goal' && value is int &&
        value > 0 && value <= 1000000) {
      return value;
    }
    throw const FormatException('Invalid Safwa backup value');
  }

  static Map<String, Object> _validateMap(Map source) {
    if (source.length > 15000) {
      throw const FormatException('Too many entries in Safwa backup');
    }
    final entries = <String, Object>{};
    for (final entry in source.entries) {
      if (entry.key is! String || entry.value is! Object) {
        throw const FormatException('Invalid backup entry');
      }
      final key = entry.key as String;
      entries[key] = _validatedValue(key, entry.value as Object);
    }
    return Map<String, Object>.unmodifiable(Map.fromEntries(
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ));
  }

  static String _checksum(Map<String, Object> values) {
    final canonical = jsonEncode({'schema': schema, 'values': values});
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Future<Map<String, Object>> _snapshot(
      SharedPreferences prefs) async {
    final values = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!_allowedKey(key)) continue;
      final item = prefs.get(key);
      if (item != null) {
        values[key] = _validatedValue(key, item);
      }
    }
    return _validateMap(values);
  }

  Future<String> createBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final values = await _snapshot(prefs);
    final body = {
      'format': format,
      'schema': schema,
      'values': values,
      'checksum_sha256': _checksum(values),
    };
    final serialized = const JsonEncoder.withIndent('  ').convert(body);
    if (serialized.length > maximumCharacters) {
      throw const FormatException('Backup exceeds supported size');
    }
    return serialized;
  }

  SafwaBackupPreview inspect(String jsonText) {
    if (jsonText.length > maximumCharacters || jsonText.isEmpty) {
      throw const FormatException('Invalid backup size');
    }
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 4 ||
        decoded['format'] != format ||
        decoded['schema'] != schema ||
        decoded['values'] is! Map<String, dynamic> ||
        decoded['checksum_sha256'] is! String) {
      throw const FormatException('Unsupported Safwa backup');
    }
    final values = _validateMap(decoded['values'] as Map<String, dynamic>);
    final checksum = _checksum(values);
    if (decoded['checksum_sha256'] != checksum) {
      throw const FormatException('Backup checksum mismatch');
    }
    return SafwaBackupPreview._(values, checksum);
  }

  static Future<void> _replace(
    SharedPreferences prefs,
    Map<String, Object> values,
  ) async {
    final existing = prefs.getKeys().where(_allowedKey).toList();
    for (final key in existing) {
      if (!values.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Unable to remove old Safwa preference');
      }
    }
    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;
      final bool saved;
      if (value is bool) {
        saved = await prefs.setBool(key, value);
      } else if (value is int) {
        saved = await prefs.setInt(key, value);
      } else if (value is double) {
        saved = await prefs.setDouble(key, value);
      } else if (value is String) {
        saved = await prefs.setString(key, value);
      } else if (value is List<String>) {
        saved = await prefs.setStringList(key, value);
      } else {
        throw StateError('Invalid validated preference type');
      }
      if (!saved) {
        throw StateError('Could not restore Safwa preference');
      }
    }
  }

  /// Explicitly requested replacement of the recognized Safwa preferences.
  /// Validation occurs before writes. Rollback is best effort and cannot
  /// guarantee all-or-nothing platform writes; tell users to retain originals.
  Future<int> restoreBackup(
    String jsonText, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw StateError('Backup restore requires explicit consent');
    }
    final incoming = inspect(jsonText);
    final prefs = await SharedPreferences.getInstance();
    final previous = await _snapshot(prefs);
    try {
      await _replace(prefs, incoming._values);
    } catch (error) {
      try {
        await _replace(prefs, previous);
      } catch (_) {
        throw StateError('Restore and rollback failed; original backup needed');
      }
      rethrow;
    }
    return incoming.keyCount;
  }
}
