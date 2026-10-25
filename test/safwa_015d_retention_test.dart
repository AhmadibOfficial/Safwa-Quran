import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_legacy_retention.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory scratch;
  late SharedPreferences legacy;
  late SafwaSqliteStore sqlite;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 23,
      'other_app_private_note': 'never-export',
    });
    legacy = await SharedPreferences.getInstance();
    scratch = await Directory.systemTemp.createTemp('safwa015d-retention-');
    sqlite = SafwaSqliteStore(
      factory: databaseFactoryFfi,
      path: '${scratch.path}/synthetic.sqlite3',
    );
    await sqlite.open();
  });

  tearDown(() async {
    await sqlite.close();
    await scratch.delete(recursive: true);
  });

  test('audit refuses before committed activation', () async {
    await expectLater(
      const SafwaLegacyRetention().auditForReview(
        legacy: legacy,
        sqlite: sqlite,
      ),
      throwsStateError,
    );
    expect(legacy.getString('other_app_private_note'), 'never-export');
  });

  test('audit reports retained shadow only, never authorizes erasure',
      () async {
    final source = LocalSafwaBackup.captureLegacyForCutover(legacy);
    await sqlite.activateValidatedLegacy(source, confirmed: true);
    final before = legacy.getKeys();
    final result = await const SafwaLegacyRetention().auditForReview(
      legacy: legacy, sqlite: sqlite,
    );
    expect(result.retainedAllowlistedKeyCount, 2);
    expect(result.matchesCutoverSource, true);
    expect(result.approvedToEraseLegacy, false);
    expect(legacy.getKeys(), before);
    expect(legacy.getString('other_app_private_note'), 'never-export');
  });

  test('changed shadow and unresolved recovery journal fail review',
      () async {
    final source = LocalSafwaBackup.captureLegacyForCutover(legacy);
    await sqlite.activateValidatedLegacy(source, confirmed: true);
    await legacy.setString('safwa_prayer_city', 'abuja');
    final changed = await const SafwaLegacyRetention().auditForReview(
      legacy: legacy, sqlite: sqlite,
    );
    expect(changed.matchesCutoverSource, false);
    expect(changed.approvedToEraseLegacy, false);
    await legacy.setString(LocalSafwaBackup.recoveryKey, '{unfinished}');
    await expectLater(
      const SafwaLegacyRetention().auditForReview(
        legacy: legacy, sqlite: sqlite,
      ),
      throwsStateError,
    );
    expect(legacy.getString(LocalSafwaBackup.recoveryKey), '{unfinished}');
  });
}
