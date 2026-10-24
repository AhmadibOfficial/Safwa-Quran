import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/encrypted_backup.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

const _passphrase = 'Safwa durable storage test passphrase 2026!';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory scratch;
  late String dbPath;
  late SafwaSqliteStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scratch = await Directory.systemTemp.createTemp('safwa015-test-');
    dbPath = '${scratch.path}/preferences.sqlite3';
    store = SafwaSqliteStore(factory: databaseFactoryFfi, path: dbPath);
    await store.open();
  });

  tearDown(() async {
    await store.close();
    // Scratch is created uniquely by this test; never touch project data.
    await scratch.delete(recursive: true);
  });

  test('new SQLite store begins with an empty allowlisted snapshot', () async {
    expect(await store.readValues(), isEmpty);
    final encoded = await store.exportValidatedJson();
    expect(const LocalSafwaBackup().inspect(encoded).keyCount, 0);
    expect(File(dbPath).existsSync(), isTrue);
  });

  test('typed values and journal entries survive close and reopen', () async {
    await store.setPreference('safwa_prayer_city', 'kaduna');
    await store.setPreference('safwa_tasbih_count', 41);
    await store.setPreference('safwa_remind_Fajr', true);
    await store.setPreference('safwa_salah_2026-10-24', ['Fajr', 'Isha']);
    await store.close();
    store = SafwaSqliteStore(factory: databaseFactoryFfi, path: dbPath);
    await store.open();
    final values = await store.readValues();
    expect(values['safwa_prayer_city'], 'kaduna');
    expect(values['safwa_tasbih_count'], 41);
    expect(values['safwa_remind_Fajr'], true);
    expect(values['safwa_salah_2026-10-24'], ['Fajr', 'Isha']);
  });

  test('transaction abort after writing never commits a partial restore',
      () async {
    await store.setPreference('safwa_prayer_city', 'kano');
    await store.setPreference('safwa_tasbih_count', 7);
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 10,
      'safwa_language': 'ha',
    });
    final replacement = await const LocalSafwaBackup().createBackupJson();
    await expectLater(
      store.restoreValidatedJson(
        replacement,
        confirmed: true,
        testCheckpointBeforeCommit: () async =>
            throw StateError('injected transaction abort'),
      ),
      throwsStateError,
    );
    expect((await store.readValues())['safwa_prayer_city'], 'kano');
    expect((await store.readValues())['safwa_tasbih_count'], 7);
    expect((await store.readValues()).containsKey('safwa_language'), false);
    await store.close();
    store = SafwaSqliteStore(factory: databaseFactoryFfi, path: dbPath);
    await store.open();
    expect((await store.readValues())['safwa_prayer_city'], 'kano');
    expect((await store.readValues())['safwa_tasbih_count'], 7);
  });

  test('successful restore atomically replaces full allowlisted snapshot',
      () async {
    await store.setPreference('safwa_language', 'en');
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'abuja',
      'safwa_tasbih_count': 99,
      'other_app_token': 'must-not-migrate',
    });
    final backup = await const LocalSafwaBackup().createBackupJson();
    expect(await store.restoreValidatedJson(backup, confirmed: true), 2);
    final current = await store.readValues();
    expect(current, {
      'safwa_prayer_city': 'abuja',
      'safwa_tasbih_count': 99,
    });
    expect(current.containsKey('other_app_token'), isFalse);
    expect(current.containsKey('safwa_language'), isFalse);
  });

  test('tampered backup cannot mutate transaction snapshot', () async {
    await store.setPreference('safwa_prayer_city', 'lagos');
    final before = await store.exportValidatedJson();
    final tampered = jsonDecode(before) as Map<String, dynamic>;
    (tampered['values'] as Map<String, dynamic>)['safwa_prayer_city'] =
        'kaduna';
    await expectLater(
      store.restoreValidatedJson(jsonEncode(tampered), confirmed: true),
      throwsFormatException,
    );
    expect(await store.exportValidatedJson(), before);
  });

  test('no consent or forbidden keys can modify SQLite store', () async {
    await store.setPreference('safwa_prayer_city', 'lagos');
    await expectLater(
      store.restoreValidatedJson(
        await store.exportValidatedJson(), confirmed: false,
      ),
      throwsStateError,
    );
    await expectLater(
      store.setPreference('quran_reader_enabled', true),
      throwsFormatException,
    );
    await expectLater(
      store.setPreference('saved_ayat', ['1:8']),
      throwsFormatException,
    );
    expect(await store.readValues(), {'safwa_prayer_city': 'lagos'});
  });

  test('encrypted imported archive is authenticated before SQLite commit',
      () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_salah_2026-10-24': ['Fajr'],
    });
    final envelope = await const EncryptedSafwaBackup()
        .createEncryptedBackup(_passphrase);
    await store.setPreference('safwa_prayer_city', 'london');
    await expectLater(
      store.restoreEncryptedJson(envelope, 'wrong strong password',
          confirmed: true),
      throwsFormatException,
    );
    expect((await store.readValues())['safwa_prayer_city'], 'london');
    expect(
      await store.restoreEncryptedJson(
        envelope, _passphrase, confirmed: true,
      ),
      2,
    );
    expect((await store.readValues())['safwa_prayer_city'], 'kaduna');
    expect((await store.readValues())['safwa_salah_2026-10-24'], ['Fajr']);
  });

  test('staging legacy data is copy-only and refuses an occupied destination',
      () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kano',
      'safwa_tasbih_goal': 33,
    });
    final legacy = await const LocalSafwaBackup().createBackupJson();
    expect(await store.stageLegacyJson(legacy, confirmed: true), 2);
    expect((await store.readValues())['safwa_prayer_city'], 'kano');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('safwa_prayer_city'), 'kano');
    await expectLater(
      store.stageLegacyJson(legacy, confirmed: true),
      throwsStateError,
    );
    expect((await store.readValues())['safwa_tasbih_goal'], 33);
  });

  test('remove mutation is transactionally committed', () async {
    await store.setPreference('safwa_prayer_city', 'kaduna');
    await store.setPreference('safwa_language', 'ha');
    await store.removePreference('safwa_language');
    expect(await store.readValues(), {'safwa_prayer_city': 'kaduna'});
    await store.close();
    store = SafwaSqliteStore(factory: databaseFactoryFfi, path: dbPath);
    await store.open();
    expect(await store.readValues(), {'safwa_prayer_city': 'kaduna'});
  });
}
