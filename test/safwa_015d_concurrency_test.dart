import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory scratch;
  late String dbPath;
  late SafwaSqliteStore primary;
  SafwaSqliteStore? secondary;

  final original = LocalSafwaBackup.encodeValidatedSnapshot(
    <String, Object>{'safwa_prayer_city': 'kaduna', 'safwa_tasbih_count': 10},
  );

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('safwa015d-synthetic-');
    dbPath = '${scratch.path}/review.sqlite3';
    primary = SafwaSqliteStore(factory: databaseFactoryFfi, path: dbPath);
    await primary.open();
  });

  tearDown(() async {
    await secondary?.close();
    await primary.close();
    // Only delete this test-owned fresh scratch directory, never any
    // repository, app database, device backup or unrelated filesystem path.
    await scratch.delete(recursive: true);
  });

  test('two independent connections reject a stale canonical writer', () async {
    await primary.activateValidatedLegacy(original, confirmed: true);
    secondary = SafwaSqliteStore(
      factory: databaseFactoryFfi, path: dbPath,
      requireExistingForReview: true,
    );
    await secondary!.open();
    final writerA = await primary.readCanonicalStateForReview();
    final writerB = await secondary!.readCanonicalStateForReview();
    expect(writerA.revision, writerB.revision);

    final result = await primary.mutateCanonicalForReview(
      expectedRevision: writerA.revision,
      transform: (values) => <String, Object>{
        ...values,
        'safwa_tasbih_count': 11,
      },
    );
    expect(result.revision, writerA.revision + 1);
    await expectLater(
      secondary!.mutateCanonicalForReview(
        expectedRevision: writerB.revision,
        transform: (values) => <String, Object>{
          ...values,
          'safwa_tasbih_count': 99,
        },
      ),
      throwsStateError,
    );
    final after = await secondary!.readCanonicalStateForReview();
    expect(after.revision, result.revision);
    expect(after.values['safwa_tasbih_count'], 11);
  });

  test('canonical writes before activation are denied', () async {
    await expectLater(
      primary.readCanonicalStateForReview(),
      throwsStateError,
    );
    await expectLater(
      primary.mutateCanonicalForReview(
        expectedRevision: 0,
        transform: (values) => <String, Object>{
          ...values, 'safwa_language': 'ha',
        },
      ),
      throwsStateError,
    );
    expect((await primary.readActivation()).active, false);
    expect(await primary.readValues(), isEmpty);
  });

  test('unfenced legacy APIs cannot write after SQLite activation', () async {
    await primary.activateValidatedLegacy(original, confirmed: true);
    await expectLater(
      primary.setPreference('safwa_tasbih_count', 999),
      throwsStateError,
    );
    await expectLater(
      primary.removePreference('safwa_prayer_city'),
      throwsStateError,
    );
    await expectLater(
      primary.restoreValidatedJson(original, confirmed: true),
      throwsStateError,
    );
    await expectLater(
      primary.stageLegacyJson(original, confirmed: true),
      throwsStateError,
    );
    expect((await primary.readCanonicalStateForReview()).values
        ['safwa_tasbih_count'], 10);
  });

  test('transaction fault leaves data and revision exactly unchanged',
      () async {
    await primary.activateValidatedLegacy(original, confirmed: true);
    final before = await primary.readCanonicalStateForReview();
    await expectLater(
      primary.mutateCanonicalForReview(
        expectedRevision: before.revision,
        transform: (values) => <String, Object>{
          ...values, 'safwa_tasbih_count': 77,
        },
        testBeforeCommit: () async {
          throw StateError('synthetic transaction failure, not SQLITE_FULL');
        },
      ),
      throwsStateError,
    );
    final after = await primary.readCanonicalStateForReview();
    expect(after.revision, before.revision);
    expect(after.values, before.values);
    await primary.close();
    await primary.open();
    final restarted = await primary.readCanonicalStateForReview();
    expect(restarted.revision, before.revision);
    expect(restarted.values, before.values);
  });

  test('existing-only open rejects missing database without recreating it',
      () async {
    final missingPath = '${scratch.path}/intentionally-absent.sqlite3';
    final missing = SafwaSqliteStore(
      factory: databaseFactoryFfi, path: missingPath,
      requireExistingForReview: true,
    );
    await expectLater(missing.open(), throwsStateError);
    expect(await File(missingPath).exists(), false);
  });

  test('corrupt snapshot fails closed on reopen, file is retained', () async {
    await primary.activateValidatedLegacy(original, confirmed: true);
    await primary.close();
    final raw = await databaseFactoryFfi.openDatabase(
      dbPath, options: OpenDatabaseOptions(singleInstance: false),
    );
    await raw.update('safwa_snapshot', {'archive': '{corrupt'});
    await raw.close();
    await expectLater(primary.open(), throwsFormatException);
    expect(await File(dbPath).exists(), true);
  });

  test('v2 snapshots upgrade to v3 revision without data loss', () async {
    final oldPath = '${scratch.path}/v2.sqlite3';
    final old = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE safwa_snapshot (
              id INTEGER NOT NULL PRIMARY KEY CHECK(id = 1),
              archive TEXT NOT NULL
            )
          ''');
          await db.insert('safwa_snapshot', {
            'id': 1, 'archive': original,
          });
          await db.execute('''
            CREATE TABLE safwa_activation (
              id INTEGER NOT NULL PRIMARY KEY CHECK(id = 1),
              state TEXT NOT NULL CHECK(state IN ('legacy', 'sqlite')),
              source_sha TEXT
            )
          ''');
          await db.insert('safwa_activation', {
            'id': 1, 'state': 'legacy', 'source_sha': null,
          });
        },
      ),
    );
    await old.close();
    final migrated = SafwaSqliteStore(
      factory: databaseFactoryFfi, path: oldPath,
      requireExistingForReview: true,
    );
    try {
      await migrated.open();
      expect((await migrated.readActivation()).active, false);
      expect((await migrated.readValues())['safwa_prayer_city'], 'kaduna');
      await migrated.activateValidatedLegacy(original, confirmed: true);
      final state = await migrated.readCanonicalStateForReview();
      expect(state.revision, 0);
      expect(state.values['safwa_tasbih_count'], 10);
    } finally {
      await migrated.close();
    }
  });
}
