import 'package:shared_preferences/shared_preferences.dart';

import 'safwa_sqlite_store.dart';

/// One typed API for Safwa preference consumers.
///
/// Runtime [getInstance] is intentionally LEGACY-only until a future
/// coordinated cutover passes all migration and device evidence gates.
/// [sqliteForVerification] is explicit and NEVER changes the live backend.
/// Code using this gateway does not by itself enable SQLite in production.
class SafwaPreferences {
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
    return legacy != null ? legacy.getKeys() : _snapshot!.keys.toSet();
  }

  bool containsKey(String key) => _legacy?.containsKey(key) ??
      _snapshot!.containsKey(key);

  Object? get(String key) => _legacy?.get(key) ?? _snapshot?[key];

  String? getString(String key) => get(key) as String?;
  bool? getBool(String key) => get(key) as bool?;
  int? getInt(String key) => get(key) as int?;
  double? getDouble(String key) => get(key) as double?;

  List<String>? getStringList(String key) {
    final value = get(key);
    return value == null ? null : List<String>.from(value as List);
  }

  Future<bool> _write(String key, Object value) async {
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
    final legacy = _legacy;
    if (legacy != null) return legacy.remove(key);
    await _sqlite!.removePreference(key);
    _snapshot!.remove(key);
    return true;
  }

  // Deliberately no generic clear(): clearing all preferences risks erasing
  // unknown legacy app keys or incomplete SAFWA-014 recovery state.
}
