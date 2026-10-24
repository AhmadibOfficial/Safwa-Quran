import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safwa_quran/companion_core.dart';
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_cutover.dart';
import 'package:safwa_quran/safwa_preferences.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory scratch;
  late String path;
  late SharedPreferences legacy;
  late SafwaSqliteStore sqlite;
  SafwaCutoverController? controller;
  var attached = false;

  Future<void> boot() async {
    sqlite = SafwaSqliteStore(factory: databaseFactoryFfi, path: path);
    await sqlite.open();
    controller = await SafwaCutoverController.openForIsolatedReview(
      legacy: legacy, sqlite: sqlite,
    );
    controller!.installForIsolatedReview();
    attached = true;
  }

  Future<void> shutDown() async {
    if (attached) {
      controller!.detachForIsolatedReview();
      attached = false;
    }
    await sqlite.close();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 11,
      'safwa_salah_2026-10-24': <String>['Fajr'],
      'saved_surahs': <String>['1', '2'],
      'unrelated_secret': 'preserve',
    });
    legacy = await SharedPreferences.getInstance();
    scratch = await Directory.systemTemp.createTemp('safwa015c-');
    path = '${scratch.path}/cutover.sqlite3';
    await boot();
  });

  tearDown(() async {
    await shutDown();
    await scratch.delete(recursive: true);
  });

  test('legacy remains the only canonical backend before activation', () async {
    final session = await SafwaPreferences.getInstance();
    expect(session.isSqliteCanonical, false);
    expect(session.getString('safwa_prayer_city'), 'kaduna');
    await session.setString('safwa_prayer_city', 'abuja');
    expect(legacy.getString('safwa_prayer_city'), 'abuja');
    expect((await sqlite.readActivation()).active, false);
  });

  test('snapshot and marker commit together; stale sessions now use SQLite',
      () async {
    // Acquire this session BEFORE activation; it must not retain a live
    // reference to SharedPreferences for operations performed afterwards.
    final stale = await SafwaPreferences.getInstance();
    await controller!.activateForIsolatedReview(confirmed: true);
    expect((await sqlite.readActivation()).active, true);
    expect(stale.isSqliteCanonical, true);
    expect(stale.getInt('safwa_tasbih_count'), 11);
    expect(stale.getStringList('saved_surahs'), ['1', '2']);
    await stale.setInt('safwa_tasbih_count', 12);
    expect((await sqlite.readValues())['safwa_tasbih_count'], 12);
    expect(legacy.getInt('safwa_tasbih_count'), 11);
    expect(legacy.getString('unrelated_secret'), 'preserve');
  });

  test('aborted transaction leaves legacy canonical and unchanged', () async {
    final previous = LocalSafwaBackup.captureLegacyForCutover(legacy);
    await expectLater(
      controller!.activateForIsolatedReview(
        confirmed: true,
        checkpoint: (step) async {
          if (step == 'after-snapshot') {
            throw StateError('simulated failure before transaction commit');
          }
        },
      ),
      throwsStateError,
    );
    expect((await sqlite.readActivation()).active, false);
    expect(await sqlite.readValues(), isEmpty);
    expect(LocalSafwaBackup.captureLegacyForCutover(legacy), previous);
    final current = await SafwaPreferences.getInstance();
    expect(current.isSqliteCanonical, false);
    expect(await current.setInt('safwa_tasbih_count', 19), true);
    expect(legacy.getInt('safwa_tasbih_count'), 19);
  });

  test('failure after SQLite commit locks runtime; restart never falls back',
      () async {
    await expectLater(
      controller!.activateForIsolatedReview(
        confirmed: true,
        checkpoint: (step) async {
          if (step == 'after-commit') {
            throw StateError('simulated loss after durable SQL commit');
          }
        },
      ),
      throwsStateError,
    );
    expect((await sqlite.readActivation()).active, true);
    final previousSession = await SafwaPreferences.getInstance();
    expect(() => previousSession.getString('safwa_prayer_city'),
        throwsStateError);
    await expectLater(
      previousSession.setString('safwa_prayer_city', 'london'),
      throwsStateError,
    );
    // The test mutates legacy directly to prove a new runtime does not
    // silently read from it after the SQLite activation was committed.
    await legacy.setString('safwa_prayer_city', 'kano');
    await shutDown();
    await boot();
    final restarted = await SafwaPreferences.getInstance();
    expect(restarted.isSqliteCanonical, true);
    expect(restarted.getString('safwa_prayer_city'), 'kaduna');
    expect(legacy.getString('safwa_prayer_city'), 'kano');
  });

  test('cutover freeze rejects new writes and reads during staging', () async {
    final entered = Completer<void>();
    final resume = Completer<void>();
    final before = await SafwaPreferences.getInstance();
    final migrating = controller!.activateForIsolatedReview(
      confirmed: true,
      checkpoint: (step) async {
        if (step == 'source-frozen') {
          entered.complete();
          await resume.future;
        }
      },
    );
    await entered.future;
    expect(() => before.getKeys(), throwsStateError);
    await expectLater(
      before.setInt('safwa_tasbih_count', 50),
      throwsStateError,
    );
    resume.complete();
    await migrating;
    expect(before.isSqliteCanonical, true);
    expect(before.getInt('safwa_tasbih_count'), 11);
  });

  test('restart selects SQLite after successful activation despite stale legacy',
      () async {
    await controller!.activateForIsolatedReview(confirmed: true);
    await (await SafwaPreferences.getInstance())
        .setString('safwa_prayer_city', 'abuja');
    expect(legacy.getString('safwa_prayer_city'), 'kaduna');
    await shutDown();
    await boot();
    expect((await SafwaPreferences.getInstance())
        .getString('safwa_prayer_city'), 'abuja');
    expect((await sqlite.readActivation()).active, true);
  });

  test('encrypted-backup inner restore targets SQL, not old recovery journal',
      () async {
    final archive = LocalSafwaBackup.captureLegacyForCutover(legacy);
    await controller!.activateForIsolatedReview(confirmed: true);
    await (await SafwaPreferences.getInstance())
        .setString('safwa_prayer_city', 'abuja');
    expect(await const LocalSafwaBackup().restoreBackup(
      archive, confirmed: true,
    ), 4);
    expect((await sqlite.readValues())['safwa_prayer_city'], 'kaduna');
    expect(legacy.getString('safwa_prayer_city'), 'kaduna');
    expect(legacy.containsKey(LocalSafwaBackup.recoveryKey), false);
  });

  test('privacy deletion is atomic for SQL; legacy archive remains untouched',
      () async {
    await controller!.activateForIsolatedReview(confirmed: true);
    expect(await clearSafwaLocalData(), 4);
    expect(await sqlite.readValues(), isEmpty);
    expect(legacy.getString('safwa_prayer_city'), 'kaduna');
    expect(legacy.getString('unrelated_secret'), 'preserve');
    await shutDown();
    await boot();
    expect((await SafwaPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('consent absent never activates SQLite or mutates legacy', () async {
    await expectLater(
      controller!.activateForIsolatedReview(confirmed: false),
      throwsStateError,
    );
    expect((await sqlite.readActivation()).active, false);
    expect(legacy.getInt('safwa_tasbih_count'), 11);
  });

  test('pending legacy undo journal blocks activation without erasing it',
      () async {
    await legacy.setString(LocalSafwaBackup.recoveryKey, '{unresolved}');
    await expectLater(
      controller!.activateForIsolatedReview(confirmed: true),
      throwsStateError,
    );
    expect((await sqlite.readActivation()).active, false);
    expect(legacy.getString(LocalSafwaBackup.recoveryKey), '{unresolved}');
    await shutDown();
    sqlite = SafwaSqliteStore(factory: databaseFactoryFfi, path: path);
    await sqlite.open();
    await expectLater(
      SafwaCutoverController.openForIsolatedReview(
        legacy: legacy, sqlite: sqlite,
      ),
      throwsStateError,
    );
  });

  test('committed SQL ignores stale legacy undo journal after restart',
      () async {
    await controller!.activateForIsolatedReview(confirmed: true);
    await legacy.setString(LocalSafwaBackup.recoveryKey, '{not-canonical}');
    await shutDown();
    await boot();
    final prefs = await SafwaPreferences.getInstance();
    expect(prefs.isSqliteCanonical, true);
    expect(await const LocalSafwaBackup().recoverPendingRestore(), false);
    expect(legacy.getString(LocalSafwaBackup.recoveryKey), '{not-canonical}');
  });
}
