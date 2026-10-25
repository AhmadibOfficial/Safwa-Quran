import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// SAFWA-016 source-only foundation. Neither the Quran reader nor recitation
/// playback is authorized for production in this build.
const bool safwaPublicRecitationPlaybackEnabled = false;

/// Models review evidence only; it is NOT an authoritative approval.
/// Qualified independent reviewers must validate that evidence outside code.
class OfflineRecitationTrack {
  const OfflineRecitationTrack({
    required this.reciterId,
    required this.reciterDisplayName,
    required this.surah,
    required this.ayahCount,
    required this.fileName,
    required this.fileBytes,
    required this.sha256Hex,
    required this.sourceAttribution,
    required this.redistributionRightsEvidence,
    required this.independentReviewEvidence,
  });

  final String reciterId;
  final String reciterDisplayName;
  final int surah;
  final int ayahCount;
  final String fileName;
  final int fileBytes;
  final String sha256Hex;
  final String sourceAttribution;
  final String redistributionRightsEvidence;
  final List<String> independentReviewEvidence;

  static final RegExp _reciterPattern =
      RegExp(r'^[a-z][a-z0-9_-]{1,40}$');
  static final RegExp _shaPattern = RegExp(r'^[a-f0-9]{64}$');

  factory OfflineRecitationTrack.fromJson(Map<String, dynamic> source) {
    final reciter = source['reciter_id'];
    final displayName = source['reciter_name'];
    final surah = source['surah'];
    final ayahs = source['ayah_count'];
    final fileName = source['file_name'];
    final bytes = source['file_bytes'];
    final digest = source['sha256'];
    final attribution = source['source_attribution'];
    final rights = source['redistribution_rights_evidence'];
    final reviewers = source['independent_review_evidence'];

    if (reciter is! String || !_reciterPattern.hasMatch(reciter) ||
        displayName is! String || displayName.trim().length < 2 ||
        displayName.length > 100 ||
        surah is! int || surah < 1 || surah > 114 ||
        ayahs is! int || ayahs < 1 || ayahs > 286 ||
        fileName is! String ||
        fileName != '${surah.toString().padLeft(3, '0')}_$reciter.mp3' ||
        bytes is! int || bytes < 4 || bytes > 250000000 ||
        digest is! String || !_shaPattern.hasMatch(digest) ||
        attribution is! String || attribution.trim().isEmpty ||
        attribution.length > 500 ||
        rights is! String || rights.trim().isEmpty || rights.length > 500 ||
        reviewers is! List || reviewers.length != 2 ||
        reviewers.any((e) => e is! String ||
            e.trim().length < 5 || e.length > 300) ||
        reviewers.toSet().length != 2) {
      throw const FormatException(
        'Invalid or insufficiently documented offline recitation',
      );
    }
    return OfflineRecitationTrack(
      reciterId: reciter,
      reciterDisplayName: displayName,
      surah: surah,
      ayahCount: ayahs,
      fileName: fileName,
      fileBytes: bytes,
      sha256Hex: digest,
      sourceAttribution: attribution,
      redistributionRightsEvidence: rights,
      independentReviewEvidence: List<String>.unmodifiable(
        reviewers.cast<String>(),
      ),
    );
  }
}

/// Describes a locked audio library, or a review-only provenance manifest.
/// Shipping playback stays disabled even when a test fixture says APPROVED.
class OfflineRecitationManifest {
  const OfflineRecitationManifest._(this.status, this.tracks);

  final String status;
  final List<OfflineRecitationTrack> tracks;
  bool get isLocked => status == 'LOCKED';

  /// Review-only sanity check: each whole-Surah recording must match the
  /// trusted 114-Surah catalog; this does not verify the audible recitation.
  void validateChapterCounts(List<int> counts) {
    if (counts.length != 114 ||
        counts.any((value) => value <= 0) ||
        counts.fold<int>(0, (sum, count) => sum + count) != 6236) {
      throw const FormatException('Unverified Quran chapter catalog');
    }
    for (final track in tracks) {
      if (track.ayahCount != counts[track.surah - 1]) {
        throw const FormatException('Recitation Ayah count differs from catalog');
      }
    }
  }

  factory OfflineRecitationManifest.parse(String text) {
    if (text.length > 200000 || text.isEmpty) {
      throw const FormatException('Invalid offline recitation manifest size');
    }
    final dynamic parsed = jsonDecode(text);
    if (parsed is! Map<String, dynamic> ||
        parsed['format'] != 'safwa-offline-recitation' ||
        parsed['schema'] != 1 ||
        (parsed['status'] != 'LOCKED' &&
            parsed['status'] != 'REVIEW_ONLY') ||
        parsed['tracks'] is! List) {
      throw const FormatException('Unsupported Safwa audio manifest');
    }

    final rows = parsed['tracks'] as List;
    if (rows.length > 114 * 20) {
      throw const FormatException('Excessive offline recitation entries');
    }
    if (parsed['status'] == 'LOCKED' && rows.isNotEmpty) {
      throw const FormatException(
        'Locked manifest must not contain playable audio records',
      );
    }
    final items = <OfflineRecitationTrack>[];
    final names = <String>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid track descriptor');
      }
      final track = OfflineRecitationTrack.fromJson(row);
      if (!names.add(track.fileName)) {
        throw const FormatException('Repeated offline recitation file');
      }
      items.add(track);
    }
    return OfflineRecitationManifest._(
      parsed['status'] as String,
      List<OfflineRecitationTrack>.unmodifiable(items),
    );
  }
}

/// No download, URL, media stream, or remote fallback is offered here.
/// The caller must point to an isolated, authorized test-only directory.
class LocalRecitationFileVerifier {
  const LocalRecitationFileVerifier();

  Future<String> verifiedFilePathForReview({
    required Directory reviewAudioDirectory,
    required OfflineRecitationTrack track,
  }) async {
    if (await FileSystemEntity.type(
          reviewAudioDirectory.path,
          followLinks: false,
        ) != FileSystemEntityType.directory) {
      throw StateError('Audio review root must be a real directory');
    }
    final path = '${reviewAudioDirectory.absolute.path}/${track.fileName}';
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Offline audio missing or linked outside sandbox');
    }
    final file = File(path);
    final before = await file.stat();
    if (before.size != track.fileBytes) {
      throw StateError('Offline audio byte count mismatch');
    }
    final digest = await sha256.bind(file.openRead()).first;
    final after = await file.stat();
    if (after.size != before.size ||
        after.modified != before.modified ||
        digest.toString() != track.sha256Hex) {
      throw StateError('Offline audio integrity mismatch');
    }
    return path;
  }
}
