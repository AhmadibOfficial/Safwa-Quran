import 'dart:io';

import 'package:just_audio/just_audio.dart';

import 'offline_recitation.dart';

/// File-only PLAYER ADAPTER for separately authorized synthetic review.
/// Never imported by main.dart or the shipping OfflineRecitationPage.
///
/// No `setUrl`, streaming source, network download, background entitlement,
/// automatic caching, or real Quran recitation is enabled in this milestone.
class OfflineRecitationReviewPlayer {
  OfflineRecitationReviewPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  bool _prepared = false;
  bool _disposed = false;

  Future<void> prepareFileForReview({
    required OfflineRecitationManifest manifest,
    required OfflineRecitationTrack track,
    required Directory isolatedAudioDirectory,
    required List<int> trustedChapterVerseCounts,
    required bool reviewSessionExplicitlyAuthorized,
  }) async {
    if (_disposed) throw StateError('Audio player has been disposed');
    if (!reviewSessionExplicitlyAuthorized ||
        manifest.status != 'REVIEW_ONLY' ||
        !manifest.tracks.contains(track) ||
        safwaPublicRecitationPlaybackEnabled) {
      throw StateError('Unapproved offline recitation is disabled');
    }
    manifest.validateChapterCounts(trustedChapterVerseCounts);
    _prepared = false;
    await _player.stop();
    final path = await const LocalRecitationFileVerifier()
        .verifiedFilePathForReview(
      reviewAudioDirectory: isolatedAudioDirectory,
      track: track,
    );
    // Uses a local file path, never a remote address. File format and
    // audio fidelity still require native-device decoder/reviewer testing.
    await _player.setFilePath(path);
    _prepared = true;
  }

  Future<void> play() async {
    if (!_prepared || _disposed) {
      throw StateError('No verified review audio prepared');
    }
    await _player.play();
  }

  Future<void> pause() async {
    if (!_prepared || _disposed) return;
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    if (!_prepared || _disposed || position.isNegative) {
      throw StateError('Invalid offline audio seek');
    }
    await _player.seek(position);
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
    _prepared = false;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
  }
}
