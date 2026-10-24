import 'local_backup.dart';
import 'safwa_sqlite_store.dart';

/// The result of a copy-only legacy preference migration rehearsal.
///
/// Never include actual preference values, Salah journal entries or secrets
/// in diagnostic logs; this evidence contains only validated metadata.
class SafwaMigrationRehearsalResult {
  const SafwaMigrationRehearsalResult({
    required this.preferenceKeys,
    required this.snapshotSha256,
  });

  final int preferenceKeys;
  final String snapshotSha256;
}

/// Explicitly opt-in, non-destructive rehearsal. No production activation.
///
/// SharedPreferences remains the live store. This function copies an
/// allowlisted snapshot into an EMPTY disposable/review SQLite database,
/// verifies its normalized digest and rechecks that legacy settings did not
/// change while the staging transaction was in progress.
///
/// This does not freeze other writers, guarantee future consistency, or
/// authorize switching the application to SQLite. A full migration requires
/// a single-writer cutover after all consumers use a common interface.
class SafwaMigrationRehearsal {
  const SafwaMigrationRehearsal();

  Future<SafwaMigrationRehearsalResult> stageAndVerify({
    required SafwaSqliteStore destination,
    required bool confirmed,
    Future<void> Function()? afterStageForTest,
  }) async {
    if (!confirmed) {
      throw StateError('Explicit copy-only migration consent required');
    }
    const source = LocalSafwaBackup();

    // createBackupJson refuses exports while an interrupted legacy restore
    // journal exists. Do NOT erase it or implicitly run a recovery here.
    final originalJson = await source.createBackupJson();
    final original = source.inspect(originalJson);

    await destination.stageLegacyJson(originalJson, confirmed: true);
    await afterStageForTest?.call();

    final stagedJson = await destination.exportValidatedJson();
    final staged = source.inspect(stagedJson);
    if (staged.sha256 != original.sha256 ||
        staged.keyCount != original.keyCount) {
      throw StateError('Migration rehearsal snapshot mismatch');
    }

    // A concurrent legacy write may have occurred during the copy. Refuse
    // to claim consistency if the current source no longer matches.
    final current = source.inspect(await source.createBackupJson());
    if (current.sha256 != original.sha256 ||
        current.keyCount != original.keyCount) {
      throw StateError('Legacy preferences changed during rehearsal');
    }

    return SafwaMigrationRehearsalResult(
      preferenceKeys: original.keyCount,
      snapshotSha256: original.sha256,
    );
  }
}
