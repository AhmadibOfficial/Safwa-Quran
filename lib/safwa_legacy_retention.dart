import 'package:shared_preferences/shared_preferences.dart';

import 'local_backup.dart';
import 'safwa_sqlite_store.dart';

/// Privacy-review metadata only. No preference values, Quran text, backups,
/// secrets or database paths are returned or logged.
class SafwaLegacyRetentionStatus {
  const SafwaLegacyRetentionStatus({
    required this.retainedAllowlistedKeyCount,
    required this.matchesCutoverSource,
  });

  final int retainedAllowlistedKeyCount;
  final bool matchesCutoverSource;

  // Until user consent, privacy review, backup-policy analysis, device
  // recovery and flash-storage semantics are cleared, erasure is forbidden.
  bool get approvedToEraseLegacy => false;
}

/// Read-only review of the retained plaintext legacy shadow AFTER a synthetic
/// SQLite cutover. Never deletes SharedPreferences, changes backup settings,
/// or pretends OS files/flash storage can be securely erased from Dart.
class SafwaLegacyRetention {
  const SafwaLegacyRetention();

  Future<SafwaLegacyRetentionStatus> auditForReview({
    required SharedPreferences legacy,
    required SafwaSqliteStore sqlite,
  }) async {
    final state = await sqlite.readActivation();
    if (!state.active || state.sourceSha == null) {
      throw StateError('No committed SQLite cutover for retention audit');
    }
    // Fail closed if a partially recovered SAFWA-014 undo journal remains.
    // Do not replay it into the canonical SQLite store.
    final source = LocalSafwaBackup.captureLegacyForCutover(legacy);
    final inspected = const LocalSafwaBackup().inspect(source);
    return SafwaLegacyRetentionStatus(
      retainedAllowlistedKeyCount: inspected.keyCount,
      matchesCutoverSource: inspected.sha256 == state.sourceSha,
    );
  }
}
