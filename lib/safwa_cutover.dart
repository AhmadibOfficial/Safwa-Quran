import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_backup.dart';
import 'safwa_preferences.dart';
import 'safwa_sqlite_store.dart';

/// SAFWA-015C opt-in TEST/REVIEW controller. Never installed by main().
///
/// All consumers must obtain SafwaPreferences through its existing facade.
/// Its sessions dynamically resolve this port, including pre-cutover handles.
/// This is an in-process barrier only; cross-isolate/native writers and actual
/// power-loss durability must be separately proven on physical devices.
class SafwaCutoverController implements SafwaCutoverPort {
  SafwaCutoverController._(
    this._legacy,
    this._sql,
    this._sqlMode,
    this._cached,
  );

  final SharedPreferences _legacy;
  final SafwaSqliteStore _sql;
  bool _sqlMode;
  Map<String, Object> _cached;
  bool _frozen = false;
  bool _faulted = false;
  bool _closed = false;
  Future<void> _tail = Future<void>.value();

  /// Reads the persisted SQLite activation marker BEFORE returning a usable
  /// controller. Once active, legacy values are never consulted/fallback.
  /// A failed SQL open or unreadable marker must fail the app startup closed.
  static Future<SafwaCutoverController> openForIsolatedReview({
    required SharedPreferences legacy,
    required SafwaSqliteStore sqlite,
  }) async {
    final state = await sqlite.readActivation();
    if (state.active) {
      return SafwaCutoverController._(
        legacy,
        sqlite,
        true,
        Map<String, Object>.from(await sqlite.readValues()),
      );
    }
    if (legacy.containsKey(LocalSafwaBackup.recoveryKey) ||
        LocalSafwaBackup.restoreBusy) {
      throw StateError('Unresolved legacy restore blocks SQLite migration');
    }
    return SafwaCutoverController._(
      legacy,
      sqlite,
      false,
      <String, Object>{},
    );
  }

  /// Test harness must opt in; no public app code ever calls this.
  void installForIsolatedReview() =>
      SafwaPreferences.attachIsolatedReviewPort(this);

  void _requireUsable() {
    if (_closed || _faulted || _frozen) {
      throw StateError('Safwa storage is locked during recovery or cutover');
    }
  }

  @override
  bool get sqliteCanonical {
    _requireUsable();
    return _sqlMode;
  }

  @override
  Set<String> getKeys() {
    _requireUsable();
    return _sqlMode ? _cached.keys.toSet() : _legacy.getKeys();
  }

  @override
  bool containsKey(String key) {
    _requireUsable();
    return _sqlMode ? _cached.containsKey(key) : _legacy.containsKey(key);
  }

  @override
  Object? get(String key) {
    _requireUsable();
    return _sqlMode ? _cached[key] : _legacy.get(key);
  }

  /// Serializes gateway mutations. A queued mutation accepted BEFORE the
  /// freeze completes before staging. New writes fail once frozen.
  Future<T> _serialize<T>(Future<T> Function() action) {
    _requireUsable();
    final operation = _tail.then((_) async {
      if (_closed || _faulted) {
        throw StateError('Safwa storage is unavailable');
      }
      return action();
    });
    _tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    return operation;
  }

  @override
  Future<bool> setValue(String key, Object value) => _serialize(() async {
    if (_sqlMode) {
      await _sql.setPreference(key, value);
      _cached = Map<String, Object>.from(await _sql.readValues());
      return true;
    }
    if (value is String) return _legacy.setString(key, value);
    if (value is bool) return _legacy.setBool(key, value);
    if (value is int) return _legacy.setInt(key, value);
    if (value is double) return _legacy.setDouble(key, value);
    if (value is List<String>) return _legacy.setStringList(key, value);
    throw const FormatException('Unsupported preference value type');
  });

  @override
  Future<bool> remove(String key) => _serialize(() async {
    if (_sqlMode) {
      await _sql.removePreference(key);
      _cached = Map<String, Object>.from(await _sql.readValues());
      return true;
    }
    return _legacy.remove(key);
  });

  @override
  Future<int> restoreCanonical(String archive) => _serialize(() async {
    if (!_sqlMode) throw StateError('SQLite is not authoritative');
    final count = await _sql.restoreValidatedJson(
      archive,
      confirmed: true,
    );
    _cached = Map<String, Object>.from(await _sql.readValues());
    return count;
  });

  @override
  Future<int> clearCanonical() => _serialize(() async {
    if (!_sqlMode) throw StateError('SQLite is not authoritative');
    final previousCount = _cached.length;
    final empty = LocalSafwaBackup.encodeValidatedSnapshot(
      <String, Object>{},
    );
    await _sql.restoreValidatedJson(empty, confirmed: true);
    _cached = Map<String, Object>.from(await _sql.readValues());
    return previousCount;
  });

  /// One-shot explicit review cutover: freeze new gateway reads/writes,
  /// wait for accepted writes, capture source, then transactionally commit
  /// snapshot + activation marker together in SQLite. No legacy deletion.
  ///
  /// Fault after SQL commit intentionally locks this instance: a fresh
  /// startup must select SQLite from the persistent marker. NEVER fallback.
  Future<void> activateForIsolatedReview({
    required bool confirmed,
    Future<void> Function(String step)? checkpoint,
  }) async {
    if (!confirmed) throw StateError('Explicit cutover consent required');
    _requireUsable();
    if (_sqlMode) throw StateError('Already using canonical SQLite');
    _frozen = true;
    try {
      await _tail;
      if (LocalSafwaBackup.restoreBusy ||
          _legacy.containsKey(LocalSafwaBackup.recoveryKey)) {
        throw StateError('Unresolved legacy restore blocks cutover');
      }
      final source = LocalSafwaBackup.captureLegacyForCutover(_legacy);
      if (checkpoint != null) await checkpoint('source-frozen');
      await _sql.activateValidatedLegacy(
        source,
        confirmed: true,
        checkpoint: checkpoint,
      );
      if (checkpoint != null) await checkpoint('after-commit');
      _cached = Map<String, Object>.from(await _sql.readValues());
      _sqlMode = true;
    } catch (_) {
      // A committed activation MUST NOT fall back to stale SharedPreferences
      // even if the process fails before updating its in-memory state.
      try {
        if ((await _sql.readActivation()).active) {
          _faulted = true;
        }
      } catch (_) {
        _faulted = true; // unreadable marker => fail closed
      }
      rethrow;
    } finally {
      if (!_faulted) _frozen = false;
    }
  }

  /// Only for the disposable, isolated test environment; not a method to
  /// undo a real cutover. Explicitly detach and close separately in tests.
  void detachForIsolatedReview() {
    SafwaPreferences.detachIsolatedReviewPort(this);
    _closed = true;
  }
}
