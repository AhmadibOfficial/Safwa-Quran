import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_migration_rehearsal.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory scratch;
  late SafwaSqliteStore destination;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_salah_2026-10-24': <String>['Fajr'],
      'safwa_companion_pins': <String>['qibla'],
      'unrelated_token': 'preserve-this',
    });
    scratch = await Directory.systemTemp.createTemp('safwa015-rehearsal-');
    destination = SafwaSqliteStore(
      factory: databaseFactoryFfi,
      path: '${scratch.path}/review.sqlite3',
    );
    await destination.open();
  });

  tearDown(() async {
    await destination.close();
    // Only delete the unique disposable directory created in this test.
    await scratch.delete(recursive: true);
  });

  test('copy-only staging verifies digest and preserves original data',
      () async {
    final before = await const LocalSafwaBackup().createBackupJson();
    final result = await const SafwaMigrationRehearsal().stageAndVerify(
      destination: destination,
      confirmed: true,
    );
    expect(result.preferenceKeys, 3);
    expect(result.snapshotSha256,
        const LocalSafwaBackup().inspect(before).sha256);
    expect(
      const LocalSafwaBackup().inspect(
        await destination.exportValidatedJson(),
      ).sha256,
      result.snapshotSha256,
    );
    expect(await const LocalSafwaBackup().createBackupJson(), before);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unrelated_token'), 'preserve-this');
    expect(prefs.getStringList('safwa_salah_2026-10-24'), ['Fajr']);
  });

  test('missing consent never stages data', () async {
    await expectLater(
      const SafwaMigrationRehearsal().stageAndVerify(
        destination: destination,
        confirmed: false,
      ),
      throwsStateError,
    );
    expect(await destination.readValues(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
  });

  test('concurrent legacy change is detected, never silently accepted',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      const SafwaMigrationRehearsal().stageAndVerify(
        destination: destination,
        confirmed: true,
        afterStageForTest: () async {
          await prefs.setString('safwa_prayer_city', 'kano');
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString('safwa_prayer_city'), 'kano');
    expect((await destination.readValues())['safwa_prayer_city'], 'kaduna');
    expect(prefs.getString('unrelated_token'), 'preserve-this');
  });

  test('pending legacy recovery journal blocks copy-only staging',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalSafwaBackup.recoveryKey, '{incomplete}');
    await expectLater(
      const SafwaMigrationRehearsal().stageAndVerify(
        destination: destination,
        confirmed: true,
      ),
      throwsStateError,
    );
    expect(prefs.getString(LocalSafwaBackup.recoveryKey), '{incomplete}');
    expect(await destination.readValues(), isEmpty);
  });

  test('occupied SQLite destination cannot be silently replaced', () async {
    await destination.setPreference('safwa_prayer_city', 'london');
    await expectLater(
      const SafwaMigrationRehearsal().stageAndVerify(
        destination: destination,
        confirmed: true,
      ),
      throwsStateError,
    );
    expect((await destination.readValues())['safwa_prayer_city'], 'london');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
  });
}
