import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'safwa_preferences.dart';
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

  /// Immutable, fully allowlisted typed snapshot for the SQLite transaction
  /// adapter. Does not include policy controls or Quran corpus data.
  Map<String, Object> get validatedValues =>
      Map<String, Object>.unmodifiable(_values);

  int get keyCount => _values.length;
  int get journalDays =>
      _values.keys.where((key) => key.startsWith('safwa_salah_')).length;
  int get savedSurahs =>
      (_values['saved_surahs'] as List<String>?)?.length ?? 0;
  int get savedAyat =>
      (_values['saved_ayat'] as List<String>?)?.length ?? 0;
}

/// A deterministic test seam for simulating failures after individual writes.
/// This cannot simulate actual flash-storage durability or loss of power.
typedef RestoreCheckpoint = Future<void> Function(String step);

/// Only fault-injection tests should throw this to simulate process death.
/// A real process death bypasses Dart exception handlers entirely.
class SimulatedRestoreInterruption extends Error {}

class LocalSafwaBackup {
  const LocalSafwaBackup({this.restoreCheckpoint});

  final RestoreCheckpoint? restoreCheckpoint;

  /// Reserved, non-exportable on-device undo journal. Contains plaintext
  /// preference snapshots, just like the existing legacy SharedPreferences store.
  static const recoveryKey = 'safwa_restore_recovery_v1';
  static bool _restoreBusy = false;

  static bool get restoreBusy => _restoreBusy;

  Future<void> _checkpoint(String step) async {
    final checkpoint = restoreCheckpoint;
    if (checkpoint != null) await checkpoint(step);
  }

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

  // Derived from assets/data/chapters.tsv (114 chapters, 6236 verses).
  // Keep synchronized with the verified *catalog counts*, not Quran text.
  static const List<int> _chapterVerseCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111,
    43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64,
    77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83,
    182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29,
    18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28,
    20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25,
    22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19,
    5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
    6, 3, 5, 4, 5, 6,
  ];

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
    return chapter >= 1 && chapter <= _chapterVerseCounts.length &&
        ayah >= 1 && ayah <= _chapterVerseCounts[chapter - 1];
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
      SafwaPreferences prefs) async {
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

  /// Review-only read of the underlying legacy source while a cutover
  /// controller has already blocked ALL routed application writes.
  /// Never calls the gateway (which must fail closed while frozen).
  /// Does not clear the SAFWA-014 undo journal or any original values.
  static String captureLegacyForCutover(SharedPreferences legacy) {
    if (_restoreBusy || legacy.containsKey(recoveryKey)) {
      throw StateError('Legacy restore must finish before cutover');
    }
    final values = <String, Object>{};
    for (final key in legacy.getKeys()) {
      if (!_allowedKey(key)) continue;
      final value = legacy.get(key);
      if (value != null) {
        values[key] = _validatedValue(key, value);
      }
    }
    return _encodeBackup(_validateMap(values));
  }

  Future<String> createBackupJson() async {
    final prefs = await SafwaPreferences.getInstance();
    _refusePending(prefs);
    final values = await _snapshot(prefs);
    return _encodeBackup(values);
  }

  /// Serialize only validated Safwa-owned preference values. Existing
  /// backup schema/checksum/limits are shared with the SQLite adapter.
  static String encodeValidatedSnapshot(Map<String, Object> values) {
    return _encodeBackup(_validateMap(values));
  }

  static String _encodeBackup(Map<String, Object> values) {
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

  /// Export is forbidden while a restore transaction might be incomplete.
  /// Initialization should call recoverPendingRestore before entering the app.
  static void _refusePending(SafwaPreferences prefs) {
    if (_restoreBusy || prefs.containsKey(recoveryKey)) {
      throw StateError('Safwa restore recovery must complete first');
    }
  }

  /// Recover the complete pre-restore snapshot from an on-device undo journal.
  /// Repeated calls are idempotent when all underlying legacy storage writes succeed.
  /// A corrupt journal is left intact and fails closed: no destructive reset.
  static Future<bool> _recover(SafwaPreferences prefs) async {
    if (!prefs.containsKey(recoveryKey)) return false;
    final journal = prefs.getString(recoveryKey);
    if (journal == null) {
      throw StateError('Safwa recovery journal has an unexpected type');
    }
    final original = const LocalSafwaBackup().inspect(journal);
    await _replace(prefs, original._values);
    if (!await prefs.remove(recoveryKey)) {
      throw StateError('Could not finish Safwa restore recovery');
    }
    return true;
  }

  /// Call on every app launch, before starting widgets that read local data.
  /// This is best-effort WAL-like recovery, not an atomic transaction or a
  /// guarantee against sudden power loss on legacy SharedPreferences storage.
  Future<bool> recoverPendingRestore() async {
    if (_restoreBusy) {
      throw StateError('Safwa restore already running');
    }
    _restoreBusy = true;
    try {
      final prefs = await SafwaPreferences.getInstance();
      // After a verified cutover, a stale legacy undo journal is NOT the
      // canonical state and must never be replayed into SQLite.
      if (prefs.isSqliteCanonical) return false;
      return await _recover(prefs);
    } finally {
      _restoreBusy = false;
    }
  }

  static Future<void> _replace(
    SafwaPreferences prefs,
    Map<String, Object> values, {
    RestoreCheckpoint? checkpoint,
  }) async {
    final existing = prefs.getKeys().where(_allowedKey).toList()..sort();
    for (final key in existing) {
      if (!values.containsKey(key)) {
        if (!await prefs.remove(key)) {
          throw StateError('Unable to remove old Safwa preference');
        }
        if (checkpoint != null) await checkpoint('removed:$key');
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
      if (checkpoint != null) await checkpoint('saved:$key');
    }
  }

  /// Requires explicit consent. On-device journal is written before any
  /// changes. If an interrupted process later restarts, initialization
  /// attempts to restore the old snapshot and leaves the journal on failure.
  ///
  /// The legacy SharedPreferences backend has no cross-key atomicity or fsync guarantee.
  /// This only improves best-effort recovery; production restore stays gated.
  Future<int> restoreBackup(
    String jsonText, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw StateError('Backup restore requires explicit consent');
    }
    if (_restoreBusy) {
      throw StateError('Safwa restore already running');
    }
    _restoreBusy = true;
    try {
      final prefs = await SafwaPreferences.getInstance();
      if (prefs.isSqliteCanonical) {
        // The entire authenticated/validated input is written using a single
        // SQLite transaction. Never write a plaintext legacy undo journal.
        return prefs.restoreCanonicalJson(jsonText);
      }
      await _recover(prefs);
      final incoming = inspect(jsonText);
      final previous = await _snapshot(prefs);
      final undo = _encodeBackup(previous);
      if (!await prefs.setString(recoveryKey, undo) ||
          prefs.getString(recoveryKey) != undo) {
        throw StateError('Unable to stage Safwa restore recovery');
      }
      try {
        await _checkpoint('journal-written');
        await _replace(prefs, incoming._values, checkpoint: _checkpoint);
      } catch (error) {
        // A deterministic approximation of an abrupt process exit in tests.
        // A real termination never executes this catch/finally in the process.
        if (error is SimulatedRestoreInterruption) rethrow;
        try {
          await _recover(prefs);
        } catch (_) {
          throw StateError(
            'Restore and recovery failed; retain original encrypted backup',
          );
        }
        rethrow;
      }
      if (!await prefs.remove(recoveryKey)) {
        throw StateError('Restore completed but recovery journal remains');
      }
      return incoming.keyCount;
    } finally {
      _restoreBusy = false;
    }
  }
}
