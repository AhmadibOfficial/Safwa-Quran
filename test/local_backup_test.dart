import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/local_backup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('backs up only recognized local settings and personal records', () async {
    SharedPreferences.setMockInitialValues({
      'saved_surahs': <String>['1', '2'],
      'saved_ayat': <String>['1:1'],
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 7,
      'safwa_salah_2026-10-23': <String>['Fajr', 'Dhuhr'],
      'safwa_remind_Isha': true,
      'unrelated_app_key': 'private-other',
      'safwa_unknown_future_field': 'do-not-export',
    });
    const service = LocalSafwaBackup();
    final backup = await service.createBackupJson();
    final preview = service.inspect(backup);
    expect(preview.keyCount, 6);
    expect(preview.journalDays, 1);
    expect(preview.savedSurahs, 2);
    expect(preview.savedAyat, 1);
    expect(backup, isNot(contains('private-other')));
    expect(backup, isNot(contains('do-not-export')));
    expect(backup, isNot(contains('quran_reader_enabled')));
    expect(backup, isNot(contains('public_release_enabled')));
  });

  test('consented restore replaces recognized data only', () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_salah_2026-10-19': <String>['Fajr'],
      'saved_surahs': <String>['2'],
    });
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'kano');
    await prefs.setStringList('safwa_salah_2026-10-20', <String>['Isha']);
    await prefs.setString('other_app_token', 'preserve-me');

    final count = await service.restoreBackup(archive, confirmed: true);
    expect(count, 3);
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
    expect(prefs.getStringList('safwa_salah_2026-10-19'), ['Fajr']);
    expect(prefs.getStringList('safwa_salah_2026-10-20'), isNull);
    expect(prefs.getString('other_app_token'), 'preserve-me');
  });

  test('restore without confirmation never changes a value', () async {
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'abuja');
    await expectLater(
      service.restoreBackup(archive, confirmed: false),
      throwsStateError,
    );
    expect(prefs.getString('safwa_prayer_city'), 'abuja');
  });

  test('tampered backup checksum fails before any mutation', () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
    });
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();
    final changed = archive.replaceFirst('"kaduna"', '"kano"');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'abuja');
    expect(() => service.inspect(changed), throwsFormatException);
    await expectLater(
      service.restoreBackup(changed, confirmed: true),
      throwsFormatException,
    );
    expect(prefs.getString('safwa_prayer_city'), 'abuja');
  });

  test('unknown preference fields remain blocked even with valid digest',
      () async {
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();
    final doc = jsonDecode(archive) as Map<String, dynamic>;
    final values = doc['values'] as Map<String, dynamic>;
    values['quran_reader_enabled'] = true;
    expect(
      () => service.inspect(jsonEncode(doc)),
      throwsFormatException,
    );
    values.remove('quran_reader_enabled');
    values['safwa_unknown_feature'] = 'not allowed';
    expect(
      () => service.inspect(jsonEncode(doc)),
      throwsFormatException,
    );
  });

  test('invalid values are rejected rather than silently sanitized', () async {
    const service = LocalSafwaBackup();
    final doc = jsonDecode(await service.createBackupJson())
        as Map<String, dynamic>;
    final values = doc['values'] as Map<String, dynamic>;
    values['safwa_salah_2026-02-30'] = ['Fajr'];
    expect(() => service.inspect(jsonEncode(doc)), throwsFormatException);
    values.remove('safwa_salah_2026-02-30');
    values['safwa_tasbih_count'] = -9;
    expect(() => service.inspect(jsonEncode(doc)), throwsFormatException);
    values.remove('safwa_tasbih_count');
    values['saved_ayat'] = ['1:1', '1:1'];
    expect(() => service.inspect(jsonEncode(doc)), throwsFormatException);
  });

  test('invalid schema or excessive input cannot be imported', () async {
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();
    final doc = jsonDecode(archive) as Map<String, dynamic>;
    doc['schema'] = 2;
    expect(() => service.inspect(jsonEncode(doc)), throwsFormatException);
    expect(
      () => service.inspect('a' * (LocalSafwaBackup.maximumCharacters + 1)),
      throwsFormatException,
    );
  });

  test('round-trip preserves typed values and approved Safwa domain keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'arabic_font_size': 34.0,
      'safwa_tasbih_goal': 99,
      'safwa_language': 'ha',
      'safwa_learning_progress': <String>['Memorization planning'],
      'safwa_remind_Fajr': false,
      'last_read': '2:4',
    });
    const service = LocalSafwaBackup();
    final archive = await service.createBackupJson();
    final preview = service.inspect(archive);
    expect(preview.keyCount, 6);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    expect((await service.restoreBackup(archive, confirmed: true)), 6);
    expect(prefs.getDouble('arabic_font_size'), 34.0);
    expect(prefs.getInt('safwa_tasbih_goal'), 99);
    expect(prefs.getString('safwa_language'), 'ha');
    expect(prefs.getStringList('safwa_learning_progress'),
        ['Memorization planning']);
    expect(prefs.getBool('safwa_remind_Fajr'), false);
    expect(prefs.getString('last_read'), '2:4');
  });

  testWidgets('backup screen warns and requires preview before restoring',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SafwaBackupPage()));
    await tester.pumpAndSettle();
    expect(find.text('Local Backup & Restore'), findsOneWidget);
    expect(find.byKey(const Key('backup_export')), findsOneWidget);
    expect(find.byKey(const Key('backup_restore')), findsNothing);
    expect(find.textContaining('NOT encrypted'), findsOneWidget);
    expect(find.byKey(const Key('backup_import_text')), findsOneWidget);
  });
}
