import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/local_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<String> prepareArchive() async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_tasbih_count': 1,
    });
    final archive = await const LocalSafwaBackup().createBackupJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'kano');
    await prefs.setInt('safwa_tasbih_count', 8);
    await prefs.setString('safwa_language', 'ha');
    await prefs.setString('non_safwa_secret', 'must-survive');
    return archive;
  }

  Future<void> assertOldSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('safwa_prayer_city'), 'kano');
    expect(prefs.getInt('safwa_tasbih_count'), 8);
    expect(prefs.getString('safwa_language'), 'ha');
    expect(prefs.getString('non_safwa_secret'), 'must-survive');
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isFalse);
  }

  test('simulated exit after removal replays old snapshot at restart', () async {
    final archive = await prepareArchive();
    final prefs = await SharedPreferences.getInstance();
    final interrupted = LocalSafwaBackup(
      restoreCheckpoint: (step) async {
        if (step == 'removed:safwa_language') {
          throw SimulatedRestoreInterruption();
        }
      },
    );
    await expectLater(
      interrupted.restoreBackup(archive, confirmed: true),
      throwsA(isA<SimulatedRestoreInterruption>()),
    );
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isTrue);
    expect(prefs.getString('safwa_language'), isNull);
    expect(await const LocalSafwaBackup().recoverPendingRestore(), isTrue);
    await assertOldSnapshot();
    expect(await const LocalSafwaBackup().recoverPendingRestore(), isFalse);
  });

  test('simulated exit after write recovers previous values', () async {
    final archive = await prepareArchive();
    final prefs = await SharedPreferences.getInstance();
    final interrupted = LocalSafwaBackup(
      restoreCheckpoint: (step) async {
        if (step == 'saved:safwa_prayer_city') {
          throw SimulatedRestoreInterruption();
        }
      },
    );
    await expectLater(
      interrupted.restoreBackup(archive, confirmed: true),
      throwsA(isA<SimulatedRestoreInterruption>()),
    );
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isTrue);
    expect(await const LocalSafwaBackup().recoverPendingRestore(), isTrue);
    await assertOldSnapshot();
  });

  test('handled per-key write error rolls back immediately', () async {
    final archive = await prepareArchive();
    final faulty = LocalSafwaBackup(
      restoreCheckpoint: (step) async {
        if (step == 'saved:safwa_tasbih_count') {
          throw Exception('simulated storage failure');
        }
      },
    );
    await expectLater(
      faulty.restoreBackup(archive, confirmed: true),
      throwsA(isA<Exception>()),
    );
    await assertOldSnapshot();
  });

  test('corrupted recovery journal blocks changes and is retained', () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kano',
      LocalSafwaBackup.recoveryKey: '{not-valid-json}',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      const LocalSafwaBackup().recoverPendingRestore(),
      throwsFormatException,
    );
    expect(prefs.getString('safwa_prayer_city'), 'kano');
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isTrue);
    await expectLater(
      const LocalSafwaBackup().createBackupJson(),
      throwsStateError,
    );
  });

  test('cannot overlap restore transactions', () async {
    final archive = await prepareArchive();
    final latch = Completer<void>();
    final staged = Completer<void>();
    final paused = LocalSafwaBackup(
      restoreCheckpoint: (step) async {
        if (step == 'journal-written') {
          staged.complete();
          await latch.future;
        }
      },
    );
    final first = paused.restoreBackup(archive, confirmed: true);
    // Deterministically wait until the write-ahead journal is staged.
    await staged.future;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isTrue);
    await expectLater(
      const LocalSafwaBackup().restoreBackup(archive, confirmed: true),
      throwsStateError,
    );
    latch.complete();
    expect(await first, 2);
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isFalse);
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
  });

  test('each mutation checkpoint can recover the old snapshot', () async {
    final initialArchive = await prepareArchive();
    final steps = <String>[];
    await LocalSafwaBackup(
      restoreCheckpoint: (step) async => steps.add(step),
    ).restoreBackup(initialArchive, confirmed: true);
    final mutations = steps
        .where((step) => step.startsWith('removed:') ||
            step.startsWith('saved:'))
        .toList();
    expect(mutations, isNotEmpty);
    for (final stopAt in mutations) {
      final archive = await prepareArchive();
      final interrupted = LocalSafwaBackup(
        restoreCheckpoint: (step) async {
          if (step == stopAt) throw SimulatedRestoreInterruption();
        },
      );
      await expectLater(
        interrupted.restoreBackup(archive, confirmed: true),
        throwsA(isA<SimulatedRestoreInterruption>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isTrue);
      expect(await const LocalSafwaBackup().recoverPendingRestore(), isTrue);
      await assertOldSnapshot();
    }
  });

  test('unconfirmed restore does not stage a journal', () async {
    final archive = await prepareArchive();
    await expectLater(
      const LocalSafwaBackup().restoreBackup(archive, confirmed: false),
      throwsStateError,
    );
    await assertOldSnapshot();
  });
}
