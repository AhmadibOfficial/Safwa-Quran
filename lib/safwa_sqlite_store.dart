import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common/sqlite_api.dart';

import 'encrypted_backup.dart';
import 'local_backup.dart';

/// SAFWA-015: isolated, opt-in SQLite prototype for *allowlisted* preferences.
///
/// IMPORTANT: The live application still reads/writes SharedPreferences.
/// Do not enable this as its canonical store, or direct UI restoration to it,
/// until ALL preference consumers have been migrated and device tested.
///
/// A single strictly-validated snapshot is replaced inside one SQLite
/// transaction. This removes cross-key partial restore within THIS database.
/// It does not make legacy SharedPreferences updates transactional, and the
/// database itself is not encrypted at rest.
class SafwaSqliteStore {
  SafwaSqliteStore({
    required this.factory,
    required this.path,
  });

  final DatabaseFactory factory;
  final String path;
  Database? _db;

  // Schema v2 adds a durable single-row activation marker. The marker and
  // snapshot are updated in ONE SQLite transaction.
  static const schemaVersion = 2;

  static Future<void> _createActivationTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE safwa_activation (
        id INTEGER NOT NULL PRIMARY KEY CHECK(id = 1),
        state TEXT NOT NULL CHECK(state IN ('legacy', 'sqlite')),
        source_sha TEXT
      )
    ''');
    await db.insert('safwa_activation', {
      'id': 1,
      'state': 'legacy',
      'source_sha': null,
    });
  }
  static const databaseFileName = 'safwa-private-preferences.db';

  /// For eventual mobile integration only. Not called by Safwa main().
  static Future<SafwaSqliteStore> openMobileForReview() async {
    final dbPath = '${await mobile.getDatabasesPath()}/$databaseFileName';
    final store = SafwaSqliteStore(
      factory: mobile.databaseFactory,
      path: dbPath,
    );
    await store.open();
    return store;
  }

  Database get _opened {
    final db = _db;
    if (db == null) {
      throw StateError('SAFWA-015 SQLite store is not open');
    }
    return db;
  }

  Future<void> open() async {
    if (_db != null) return;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          // WAL + FULL reduces loss of committed transactions on devices,
          // subject to the actual platform/filesystem durability behaviour.
          // Never silently continue in an unexpected persistence mode.
          // Android's sqflite backend expects journal-mode pragmas via
          // rawQuery rather than execute when the manifest owns the mode.
          await database.rawQuery('PRAGMA journal_mode=WAL');
          await database.execute('PRAGMA synchronous=FULL');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE safwa_snapshot (
              id INTEGER NOT NULL PRIMARY KEY CHECK(id = 1),
              archive TEXT NOT NULL
            )
          ''');
          await database.insert('safwa_snapshot', {
            'id': 1,
            'archive': LocalSafwaBackup.encodeValidatedSnapshot(
              <String, Object>{},
            ),
          });
          await _createActivationTable(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion != 1 || newVersion != schemaVersion) {
            throw StateError('Unsupported Safwa SQLite schema migration');
          }
          await _createActivationTable(database);
        },
      ),
    );

    try {
      final journal = await db.rawQuery('PRAGMA journal_mode');
      final sync = await db.rawQuery('PRAGMA synchronous');
      final journalValue = journal.first.values.first.toString().toLowerCase();
      final synchronousValue = sync.first.values.first;
      if (journalValue != 'wal' ||
          synchronousValue is! num ||
          synchronousValue.toInt() != 2) {
        throw StateError('SAFWA-015 requires WAL and synchronous=FULL');
      }
      // Every open verifies the stored allowlist and SHA-256 checksum.
      const LocalSafwaBackup().inspect(await _readArchive(db));
      await _readActivation(db);
      _db = db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<String> _readArchive(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'safwa_snapshot',
      columns: ['archive'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.length != 1 || rows.first['archive'] is! String) {
      throw StateError('SAFWA-015 preference snapshot missing or corrupt');
    }
    return rows.single['archive']! as String;
  }

  /// Throws on invalid, missing, or unknown activation metadata; never
  /// silently assumes legacy when a marker is malformed.
  static Future<({bool active, String? sourceSha})> _readActivation(
    DatabaseExecutor executor,
  ) async {
    final records = await executor.query(
      'safwa_activation',
      columns: ['state', 'source_sha'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (records.length != 1) {
      throw StateError('Missing Safwa cutover activation record');
    }
    final state = records.single['state'];
    final hash = records.single['source_sha'];
    if (state == 'legacy' && hash == null) {
      return (active: false, sourceSha: null);
    }
    if (state == 'sqlite' && hash is String &&
        RegExp(r'^[0-9a-f]{64}
  /// reviewer records, Quran text, unknown future keys or other-app secrets.
  Future<Map<String, Object>> readValues() async {
    final archive = await _readArchive(_opened);
    return const LocalSafwaBackup().inspect(archive).validatedValues;
  }

  Future<String> exportValidatedJson() => _readArchive(_opened);

  Future<void> setPreference(String key, Object value) async {
    await _opened.transaction((txn) async {
      final previous = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      final updated = <String, Object>{...previous, key: value};
      await _writeArchive(
        txn,
        LocalSafwaBackup.encodeValidatedSnapshot(updated),
      );
    });
  }

  Future<void> removePreference(String key) async {
    await _opened.transaction((txn) async {
      final previous = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      if (!previous.containsKey(key)) return;
      final updated = <String, Object>{...previous}..remove(key);
      await _writeArchive(
        txn,
        LocalSafwaBackup.encodeValidatedSnapshot(updated),
      );
    });
  }

  static Future<void> _writeArchive(
    Transaction txn,
    String validatedArchive,
  ) async {
    final changed = await txn.update(
      'safwa_snapshot',
      {'archive': validatedArchive},
      where: 'id = ?',
      whereArgs: [1],
    );
    if (changed != 1) throw StateError('SAFWA-015 snapshot update failed');
  }

  /// One transactional replacement, with an optional deterministic failure
  /// seam used by TESTS ONLY. Throws inside the transaction roll everything
  /// back; successful completion commits a single complete replacement.
  Future<int> restoreValidatedJson(
    String backupJson, {
    required bool confirmed,
    Future<void> Function()? testCheckpointBeforeCommit,
  }) async {
    if (!confirmed) throw StateError('Explicit restore consent required');
    // Validate untrusted input BEFORE a database transaction or mutation.
    final checked = const LocalSafwaBackup().inspect(backupJson);
    final serialized = LocalSafwaBackup.encodeValidatedSnapshot(
      checked.validatedValues,
    );
    await _opened.transaction((txn) async {
      await _writeArchive(txn, serialized);
      await testCheckpointBeforeCommit?.call();
    });
    return checked.keyCount;
  }

  /// Decrypt and validate off-database, then transactionally replace.
  /// This is NOT yet wired to the live backup UI or SharedPreferences store.
  Future<int> restoreEncryptedJson(
    String envelope,
    String passphrase, {
    required bool confirmed,
    Future<void> Function()? testCheckpointBeforeCommit,
  }) async {
    if (!confirmed) throw StateError('Explicit restore consent required');
    final inspected = await const EncryptedSafwaBackup()
        .inspect(envelope, passphrase);
    final validatedArchive = LocalSafwaBackup.encodeValidatedSnapshot(
      inspected.validatedValues,
    );
    return restoreValidatedJson(
      validatedArchive,
      confirmed: true,
      testCheckpointBeforeCommit: testCheckpointBeforeCommit,
    );
  }

  /// Explicit, NON-DESTRUCTIVE one-way staging for planned migration. This
  /// never clears SharedPreferences, and refuses to overwrite any SQLite data.
  /// Legacy and SQLite must not become simultaneous production writers.
  Future<int> stageLegacyJson(
    String legacyBackupJson, {
    required bool confirmed,
  }) async {
    if (!confirmed) throw StateError('Explicit staging consent required');
    final inspected = const LocalSafwaBackup().inspect(legacyBackupJson);
    final archive = LocalSafwaBackup.encodeValidatedSnapshot(
      inspected.validatedValues,
    );
    await _opened.transaction((txn) async {
      final existing = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      if (existing.isNotEmpty) {
        throw StateError('Refusing to overwrite an existing SQLite snapshot');
      }
      await _writeArchive(txn, archive);
    });
    return inspected.keyCount;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }
}
).hasMatch(hash)) {
      return (active: true, sourceSha: hash);
    }
    throw StateError('Invalid Safwa cutover activation record');
  }

  Future<({bool active, String? sourceSha})> readActivation() =>
      _readActivation(_opened);

  /// Opt-in *review-only* cutover. Source bytes and activation marker must
  /// commit or rollback together. Do not call from the production app.
  ///
  /// A previous rehearsal is acceptable ONLY if byte-normalized content
  /// matches the expected source. Disallow overwriting unrelated SQL state.
  Future<void> activateValidatedLegacy(
    String sourceBackup, {
    required bool confirmed,
    Future<void> Function(String step)? checkpoint,
  }) async {
    if (!confirmed) {
      throw StateError('Explicit cutover consent required');
    }
    final checked = const LocalSafwaBackup().inspect(sourceBackup);
    final canonical = LocalSafwaBackup.encodeValidatedSnapshot(
      checked.validatedValues,
    );
    await _opened.transaction((txn) async {
      final state = await _readActivation(txn);
      if (state.active) {
        throw StateError('SQLite backend already activated');
      }
      final old = const LocalSafwaBackup()
          .inspect(await _readArchive(txn));
      if (old.keyCount != 0 && old.sha256 != checked.sha256) {
        throw StateError('SQLite destination contains divergent data');
      }
      if (checkpoint != null) await checkpoint('before-snapshot');
      await _writeArchive(txn, canonical);
      if (checkpoint != null) await checkpoint('after-snapshot');
      final changed = await txn.update(
        'safwa_activation',
        {'state': 'sqlite', 'source_sha': checked.sha256},
        where: 'id = ? AND state = ?',
        whereArgs: [1, 'legacy'],
      );
      if (changed != 1) {
        throw StateError('Unable to commit Safwa cutover marker');
      }
      if (checkpoint != null) await checkpoint('after-marker');
    });
  }

  /// Returns a validated snapshot. It never includes reader-release policy,
  /// reviewer records, Quran text, unknown future keys or other-app secrets.
  Future<Map<String, Object>> readValues() async {
    final archive = await _readArchive(_opened);
    return const LocalSafwaBackup().inspect(archive).validatedValues;
  }

  Future<String> exportValidatedJson() => _readArchive(_opened);

  Future<void> setPreference(String key, Object value) async {
    await _opened.transaction((txn) async {
      final previous = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      final updated = <String, Object>{...previous, key: value};
      await _writeArchive(
        txn,
        LocalSafwaBackup.encodeValidatedSnapshot(updated),
      );
    });
  }

  Future<void> removePreference(String key) async {
    await _opened.transaction((txn) async {
      final previous = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      if (!previous.containsKey(key)) return;
      final updated = <String, Object>{...previous}..remove(key);
      await _writeArchive(
        txn,
        LocalSafwaBackup.encodeValidatedSnapshot(updated),
      );
    });
  }

  static Future<void> _writeArchive(
    Transaction txn,
    String validatedArchive,
  ) async {
    final changed = await txn.update(
      'safwa_snapshot',
      {'archive': validatedArchive},
      where: 'id = ?',
      whereArgs: [1],
    );
    if (changed != 1) throw StateError('SAFWA-015 snapshot update failed');
  }

  /// One transactional replacement, with an optional deterministic failure
  /// seam used by TESTS ONLY. Throws inside the transaction roll everything
  /// back; successful completion commits a single complete replacement.
  Future<int> restoreValidatedJson(
    String backupJson, {
    required bool confirmed,
    Future<void> Function()? testCheckpointBeforeCommit,
  }) async {
    if (!confirmed) throw StateError('Explicit restore consent required');
    // Validate untrusted input BEFORE a database transaction or mutation.
    final checked = const LocalSafwaBackup().inspect(backupJson);
    final serialized = LocalSafwaBackup.encodeValidatedSnapshot(
      checked.validatedValues,
    );
    await _opened.transaction((txn) async {
      await _writeArchive(txn, serialized);
      await testCheckpointBeforeCommit?.call();
    });
    return checked.keyCount;
  }

  /// Decrypt and validate off-database, then transactionally replace.
  /// This is NOT yet wired to the live backup UI or SharedPreferences store.
  Future<int> restoreEncryptedJson(
    String envelope,
    String passphrase, {
    required bool confirmed,
    Future<void> Function()? testCheckpointBeforeCommit,
  }) async {
    if (!confirmed) throw StateError('Explicit restore consent required');
    final inspected = await const EncryptedSafwaBackup()
        .inspect(envelope, passphrase);
    final validatedArchive = LocalSafwaBackup.encodeValidatedSnapshot(
      inspected.validatedValues,
    );
    return restoreValidatedJson(
      validatedArchive,
      confirmed: true,
      testCheckpointBeforeCommit: testCheckpointBeforeCommit,
    );
  }

  /// Explicit, NON-DESTRUCTIVE one-way staging for planned migration. This
  /// never clears SharedPreferences, and refuses to overwrite any SQLite data.
  /// Legacy and SQLite must not become simultaneous production writers.
  Future<int> stageLegacyJson(
    String legacyBackupJson, {
    required bool confirmed,
  }) async {
    if (!confirmed) throw StateError('Explicit staging consent required');
    final inspected = const LocalSafwaBackup().inspect(legacyBackupJson);
    final archive = LocalSafwaBackup.encodeValidatedSnapshot(
      inspected.validatedValues,
    );
    await _opened.transaction((txn) async {
      final existing = const LocalSafwaBackup()
          .inspect(await _readArchive(txn)).validatedValues;
      if (existing.isNotEmpty) {
        throw StateError('Refusing to overwrite an existing SQLite snapshot');
      }
      await _writeArchive(txn, archive);
    });
    return inspected.keyCount;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }
}
