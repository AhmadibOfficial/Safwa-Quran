import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:safwa_quran/local_backup.dart';
import 'package:safwa_quran/safwa_sqlite_store.dart';

/// SAFWA-015D: MANUALLY OPTED-IN synthetic Android/iOS device harness.
///
/// Never imported by main.dart and never run by the default flutter test suite.
/// Install ONLY in a separately identified disposable test app. No personal
/// Quran preferences, real-user restore or operating-system permissions.
/// Use a device-testing operator for hold-* phases and never automate killing
/// the user's development terminal or unrelated Android/iOS applications.
const phase = String.fromEnvironment('SAFWA_015D_PHASE', defaultValue: '');

const deviceFileName = 'safwa015d-synthetic-review-only.sqlite3';
final synthetic = LocalSafwaBackup.encodeValidatedSnapshot(<String, Object>{
  'safwa_prayer_city': 'kaduna',
  'safwa_tasbih_count': 23,
  'saved_surahs': <String>['1', '2'],
  'safwa_remind_Fajr': true,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SAFWA-015D operator-controlled sandbox recovery', (_) async {
    const permitted = <String>{
      'prepare', 'verify-legacy', 'activate', 'verify-active',
      'hold-before-commit', 'hold-after-commit', 'cleanup',
    };
    if (!permitted.contains(phase)) {
      throw StateError(
        'No authorized test phase. Specify a documented SAFWA_015D_PHASE '
        'in a disposable installed test app.',
      );
    }
    final directory = await mobile.getDatabasesPath();
    // Never accept externally supplied absolute paths: test-owned name only.
    final dbPath = '$directory/$deviceFileName';
    final exists = await File(dbPath).exists();

    if (phase == 'cleanup') {
      // Explicit operator request only. Verify the EXACT synthetic path.
      if (!dbPath.endsWith('/$deviceFileName')) {
        throw StateError('Refusing unsafe SQLite cleanup path');
      }
      if (exists) await mobile.deleteDatabase(dbPath);
      expect(await File(dbPath).exists(), false);
      return;
    }

    if (phase == 'prepare') {
      if (exists) {
        throw StateError(
          'Synthetic database already exists; refuse to overwrite it',
        );
      }
      final created = SafwaSqliteStore(
        factory: mobile.databaseFactory,
        path: dbPath,
      );
      try {
        await created.open();
        expect((await created.readActivation()).active, false);
        expect(await created.readValues(), isEmpty);
      } finally {
        await created.close();
      }
      return;
    }

    // All phases except 'prepare' fail closed if the test DB disappeared.
    final store = SafwaSqliteStore(
      factory: mobile.databaseFactory,
      path: dbPath,
      requireExistingForReview: true,
    );
    await store.open();
    try {
      if (phase == 'verify-legacy') {
        expect((await store.readActivation()).active, false);
        expect(await store.readValues(), isEmpty);
      } else if (phase == 'verify-active') {
        expect((await store.readActivation()).active, true);
        final state = await store.readCanonicalStateForReview();
        expect(state.values['safwa_prayer_city'], 'kaduna');
        expect(state.values['safwa_tasbih_count'], 23);
        expect(state.values['saved_surahs'], ['1', '2']);
        expect(state.values['safwa_remind_Fajr'], true);
      } else if (phase == 'activate') {
        await store.activateValidatedLegacy(synthetic, confirmed: true);
        expect((await store.readActivation()).active, true);
      } else if (phase == 'hold-before-commit') {
        // Operator force-stops the disposable test app AFTER the snapshot and
        // marker have been written INSIDE an uncommitted SQL transaction.
        // There is no Dart finally after OS force-stop. On next launch,
        // 'verify-legacy' must see the unactivated, empty snapshot.
        await store.activateValidatedLegacy(
          synthetic,
          confirmed: true,
          checkpoint: (step) async {
            if (step == 'after-marker') {
              await Completer<void>().future; // intentional operator hold
            }
          },
        );
        fail('Hold was unexpectedly released without OS termination');
      } else if (phase == 'hold-after-commit') {
        // Operator force-stops AFTER SQLite commit but BEFORE the Dart
        // controller switches its in-memory backend.
        await store.activateValidatedLegacy(synthetic, confirmed: true);
        await Completer<void>().future; // intentional operator hold
        fail('Hold was unexpectedly released without OS termination');
      }
    } finally {
      await store.close();
    }
  });
}
