import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_preferences.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 10,
      'other_app_secret': 'leave-alone',
    });
  });

  test('default gateway remains the existing SharedPreferences backend',
      () async {
    final store = await SafwaPreferences.getInstance();
    expect(store.getString('safwa_prayer_city'), 'kaduna');
    expect(store.getInt('safwa_tasbih_count'), 10);
    expect(await store.setString('safwa_prayer_city', 'abuja'), isTrue);
    expect(await store.setInt('safwa_tasbih_count', 11), isTrue);
    final original = await SharedPreferences.getInstance();
    expect(original.getString('safwa_prayer_city'), 'abuja');
    expect(original.getInt('safwa_tasbih_count'), 11);
    expect(original.getString('other_app_secret'), 'leave-alone');
    expect(store.containsKey('other_app_secret'), isTrue);
  });

  test('backup remains on legacy data and excludes unrelated keys',
      () async {
    final prefs = await SafwaPreferences.getInstance();
    await prefs.setStringList('saved_surahs', ['1', '2']);
    final archive = await const LocalSafwaBackup().createBackupJson();
    final inspected = const LocalSafwaBackup().inspect(archive);
    expect(inspected.keyCount, 3);
    expect(archive, isNot(contains('other_app_secret')));
    expect(archive, isNot(contains('leave-alone')));
  });

  test('gateway returns detached list copies', () async {
    final prefs = await SafwaPreferences.getInstance();
    await prefs.setStringList('saved_surahs', ['1']);
    final values = prefs.getStringList('saved_surahs')!;
    values.add('2');
    expect(prefs.getStringList('saved_surahs'), ['1']);
  });

  test('SQLite review session is isolated from default live backend',
      () async {
    final dir = await Directory.systemTemp.createTemp('safwa-gateway-');
    final sql = SafwaSqliteStore(
      factory: databaseFactoryFfi,
      path: '${dir.path}/review.sqlite3',
    );
    try {
      await sql.open();
      final review = await SafwaPreferences.sqliteForVerification(sql);
      expect(review.getKeys(), isEmpty);
      expect(await review.setString('safwa_prayer_city', 'london'), isTrue);
      expect(await review.setBool('safwa_remind_Fajr', true), isTrue);
      expect(review.getString('safwa_prayer_city'), 'london');
      expect(review.getBool('safwa_remind_Fajr'), isTrue);
      expect(review.getKeys(),
          containsAll(<String>['safwa_prayer_city', 'safwa_remind_Fajr']));
      expect((await SafwaPreferences.getInstance())
          .getString('safwa_prayer_city'), 'kaduna');
      expect((await SharedPreferences.getInstance())
          .getString('other_app_secret'), 'leave-alone');
      await expectLater(
        review.setString('quran_reader_enabled', 'true'),
        throwsFormatException,
      );
      expect((await sql.readValues()).containsKey('quran_reader_enabled'),
          isFalse);
      expect(await review.remove('safwa_remind_Fajr'), isTrue);
      expect((await sql.readValues()).containsKey('safwa_remind_Fajr'), isFalse);
    } finally {
      await sql.close();
      // Directory was uniquely created by this test only.
      await dir.delete(recursive: true);
    }
  });

  test('legacy undo journal still blocks unsafe backup export', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalSafwaBackup.recoveryKey, '{unfinished');
    await expectLater(
      const LocalSafwaBackup().createBackupJson(),
      throwsStateError,
    );
    expect(prefs.getString(LocalSafwaBackup.recoveryKey), '{unfinished');
  });
}
