import 'package:shared_preferences/shared_preferences.dart';

import 'safwa_sqlite_store.dart';

/// One typed API for Safwa preference consumers.
///
/// Runtime [getInstance] is intentionally LEGACY-only until a future
/// coordinated cutover passes all migration and device evidence gates.
/// [sqliteForVerification] is explicit and NEVER changes the live backend.
/// Code using this gateway does not by itself enable SQLite in production.
/// Internal experimental cutover interface. The production runtime NEVER
/// installs one. Existing preference objects consult this port on EVERY
/// access, so stale handles cannot silently continue using legacy storage.
abstract class SafwaCutoverPort {
  Set<String> getKeys();
  bool containsKey(String key);
  Object? get(String key);
  Future<bool> setValue(String key, Object value);
  Future<bool> remove(String key);
  bool get sqliteCanonical;
  Future<int> restoreCanonical(String archive);
  Future<int> clearCanonical();
}

class SafwaPreferences {
  static SafwaCutoverPort? _isolatedReviewPort;

  /// For isolated synthetic tests only; NOT called by main(), app startup,
  /// preferences UI, backup screen or any shipping route.
  static void attachIsolatedReviewPort(SafwaCutoverPort port) {
    if (_isolatedReviewPort != null) {
      throw StateError('A cutover review session is already active');
    }
    _isolatedReviewPort = port;
  }

  static void detachIsolatedReviewPort(SafwaCutoverPort port) {
    if (!identical(_isolatedReviewPort, port)) {
      throw StateError('Cannot detach unrelated review session');
    }
    _isolatedReviewPort = null;
  }

  // Indirection also covers preference objects acquired before the review
  // runtime was installed. Explicit SQLite verification sessions are separate.
  SafwaCutoverPort? get _port =>
      _sqlite == null ? _isolatedReviewPort : null;

  bool get isSqliteCanonical =>
      _port?.sqliteCanonical ?? (_sqlite != null);

  Future<int> restoreCanonicalJson(String archive) async {
    final p = _port;
    if (p == null || !p.sqliteCanonical) {
      throw StateError('SQLite canonical restore is not active');
    }
    return p.restoreCanonical(archive);
  }

  Future<int> clearCanonicalData() async {
    final p = _port;
    if (p == null || !p.sqliteCanonical) {
      throw StateError('SQLite canonical erasure is not active');
    }
    return p.clearCanonical();
  }

  SafwaPreferences._legacy(this._legacy)
      : _sqlite = null,
        _snapshot = null;

  SafwaPreferences._sqlite(this._sqlite, Map<String, Object> values)
      : _legacy = null,
        _snapshot = Map<String, Object>.from(values);

  final SharedPreferences? _legacy;
  final SafwaSqliteStore? _sqlite;
  final Map<String, Object>? _snapshot;

  /// Existing behaviour remains intact for all application screens.
  static Future<SafwaPreferences> getInstance() async =>
      SafwaPreferences._legacy(await SharedPreferences.getInstance());

  /// An explicit, isolated factory for widget/unit verification only.
  /// Callers must supply a previously opened, disposable SQLite instance.
  /// This does not activate SQLite for other screens or app startup.
  static Future<SafwaPreferences> sqliteForVerification(
    SafwaSqliteStore store,
  ) async =>
      SafwaPreferences._sqlite(store, await store.readValues());

  Set<String> getKeys() {
    final legacy = _legacy;
    final port = _port;
    if (port != null) return port.getKeys();
    return legacy != null ? legacy.getKeys() : _snapshot!.keys.toSet();
  }

  bool containsKey(String key) {
    final port = _port;
    if (port != null) return port.containsKey(key);
    return _legacy?.containsKey(key) ?? _snapshot!.containsKey(key);
  }

  Object? get(String key) {
    final port = _port;
    if (port != null) return port.get(key);
    return _legacy?.get(key) ?? _snapshot?[key];
  }

  String? getString(String key) => get(key) as String?;
  bool? getBool(String key) => get(key) as bool?;
  int? getInt(String key) => get(key) as int?;
  double? getDouble(String key) => get(key) as double?;

  List<String>? getStringList(String key) {
    final value = get(key);
    return value == null ? null : List<String>.from(value as List);
  }

  Future<bool> _write(String key, Object value) async {
    final port = _port;
    if (port != null) return port.setValue(key, value);
    final legacy = _legacy;
    if (legacy != null) {
      if (value is String) return legacy.setString(key, value);
      if (value is bool) return legacy.setBool(key, value);
      if (value is int) return legacy.setInt(key, value);
      if (value is double) return legacy.setDouble(key, value);
      if (value is List<String>) return legacy.setStringList(key, value);
      throw const FormatException('Unsupported preference value type');
    }
    await _sqlite!.setPreference(key, value);
    _snapshot![key] = value is List<String>
        ? List<String>.unmodifiable(value)
        : value;
    return true;
  }

  Future<bool> setString(String key, String value) => _write(key, value);
  Future<bool> setBool(String key, bool value) => _write(key, value);
  Future<bool> setInt(String key, int value) => _write(key, value);
  Future<bool> setDouble(String key, double value) => _write(key, value);
  Future<bool> setStringList(String key, List<String> value) =>
      _write(key, value);

  Future<bool> remove(String key) async {
    final port = _port;
    if (port != null) return port.remove(key);
    final legacy = _legacy;
    if (legacy != null) return legacy.remove(key);
    await _sqlite!.removePreference(key);
    _snapshot!.remove(key);
    return true;
  }

  // Deliberately no generic clear(): clearing all preferences risks erasing
  // unknown legacy app keys or incomplete SAFWA-014 recovery state.
}
