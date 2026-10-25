import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safwa_quran/offline_recitation.dart';
import 'package:safwa_quran/offline_recitation_page.dart';
import 'package:safwa_quran/quran_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleAudio = <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x01];
  final sampleHash = sha256.convert(sampleAudio).toString();

  Map<String, dynamic> sampleTrack() => <String, dynamic>{
        'reciter_id': 'review_reciter',
        'reciter_name': 'Synthetic Review Recording',
        'surah': 1,
        'ayah_count': 7,
        'file_name': '001_review_reciter.mp3',
        'file_bytes': sampleAudio.length,
        'sha256': sampleHash,
        'source_attribution': 'SYNTHETIC TEST FIXTURE - NO QURAN AUDIO',
        'redistribution_rights_evidence':
            'LOCAL TEST FILE - NOT A REAL CONTENT LICENSE',
        'independent_review_evidence': <String>[
          'SYNTHETIC-TEST-REVIEW-ONE',
          'SYNTHETIC-TEST-REVIEW-TWO',
        ],
      };

  String manifest({
    String status = 'REVIEW_ONLY',
    List<Map<String, dynamic>>? tracks,
  }) =>
      jsonEncode(<String, dynamic>{
        'format': 'safwa-offline-recitation',
        'schema': 1,
        'status': status,
        'tracks': tracks ?? <Map<String, dynamic>>[sampleTrack()],
      });

  test('locked empty manifest has no playable recordings', () {
    final catalog = OfflineRecitationManifest.parse(
      manifest(status: 'LOCKED', tracks: <Map<String, dynamic>>[]),
    );
    expect(catalog.isLocked, true);
    expect(catalog.tracks, isEmpty);
    expect(safwaPublicRecitationPlaybackEnabled, false);
  });

  test('locked manifest refuses even documented audio tracks', () {
    expect(
      () => OfflineRecitationManifest.parse(
        manifest(status: 'LOCKED'),
      ),
      throwsFormatException,
    );
  });

  test('malformed status and JSON fail closed', () {
    expect(() => OfflineRecitationManifest.parse('{bad'),
        throwsFormatException);
    expect(
      () => OfflineRecitationManifest.parse(manifest(status: 'APPROVED')),
      throwsFormatException,
    );
  });

  test('missing redistribution rights evidence is denied', () {
    final item = sampleTrack()..remove('redistribution_rights_evidence');
    expect(
      () => OfflineRecitationManifest.parse(manifest(tracks: [item])),
      throwsFormatException,
    );
  });

  test('independent reviewer evidence must be distinct and present', () {
    final item = sampleTrack()
      ..['independent_review_evidence'] = <String>['duplicate', 'duplicate'];
    expect(
      () => OfflineRecitationManifest.parse(manifest(tracks: [item])),
      throwsFormatException,
    );
  });

  test('file name traversal, URL or wrong Surah path is denied', () {
    for (final unsafe in <String>[
      '../001_review_reciter.mp3',
      '/tmp/001_review_reciter.mp3',
      'https://example.test/file.mp3',
      '002_review_reciter.mp3',
    ]) {
      final item = sampleTrack()..['file_name'] = unsafe;
      expect(
        () => OfflineRecitationManifest.parse(manifest(tracks: [item])),
        throwsFormatException,
      );
    }
  });

  test('duplicate recording descriptors fail closed', () {
    expect(
      () => OfflineRecitationManifest.parse(
        manifest(tracks: [sampleTrack(), sampleTrack()]),
      ),
      throwsFormatException,
    );
  });

  test('valid synthetic review-only descriptor is typed and bounded', () {
    final parsed = OfflineRecitationManifest.parse(manifest());
    expect(parsed.isLocked, false);
    expect(parsed.tracks.single.surah, 1);
    expect(parsed.tracks.single.ayahCount, 7);
    expect(parsed.tracks.single.fileName, '001_review_reciter.mp3');
    expect(safwaPublicRecitationPlaybackEnabled, false);
  });

  test('synthetic whole-Surah descriptor matches the chapter catalog',
      () async {
    final chapters = await const QuranData().chapters();
    final counts = chapters.map((entry) => entry.verseCount).toList();
    final parsed = OfflineRecitationManifest.parse(manifest());
    expect(() => parsed.validateChapterCounts(counts), returnsNormally);
  });

  test('recitation with incorrect Ayah count fails catalog cross-check',
      () async {
    final chapters = await const QuranData().chapters();
    final counts = chapters.map((entry) => entry.verseCount).toList();
    final forged = sampleTrack()..['ayah_count'] = 8;
    final parsed = OfflineRecitationManifest.parse(
      manifest(tracks: [forged]),
    );
    expect(() => parsed.validateChapterCounts(counts), throwsFormatException);
  });

  test('offline verifier hashes only an isolated exact local file', () async {
    final root = await Directory.systemTemp.createTemp('safwa016-audio-');
    try {
      final item = OfflineRecitationManifest.parse(manifest()).tracks.single;
      final file = File('${root.path}/${item.fileName}');
      await file.writeAsBytes(sampleAudio);
      final path = await const LocalRecitationFileVerifier()
          .verifiedFilePathForReview(
        reviewAudioDirectory: root,
        track: item,
      );
      expect(path, file.absolute.path);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('modified local file with same size is rejected', () async {
    final root = await Directory.systemTemp.createTemp('safwa016-tamper-');
    try {
      final item = OfflineRecitationManifest.parse(manifest()).tracks.single;
      await File('${root.path}/${item.fileName}')
          .writeAsBytes(<int>[0x49, 0x44, 0x33, 0x04, 0, 0, 0x02]);
      await expectLater(
        const LocalRecitationFileVerifier().verifiedFilePathForReview(
          reviewAudioDirectory: root,
          track: item,
        ),
        throwsStateError,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('missing audio fails closed without network fallback', () async {
    final root = await Directory.systemTemp.createTemp('safwa016-missing-');
    try {
      final item = OfflineRecitationManifest.parse(manifest()).tracks.single;
      await expectLater(
        const LocalRecitationFileVerifier().verifiedFilePathForReview(
          reviewAudioDirectory: root,
          track: item,
        ),
        throwsStateError,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  testWidgets('offline recitation screen remains a non-playable status',
      (tester) async {
    final locked = OfflineRecitationManifest.parse(
      manifest(status: 'LOCKED', tracks: <Map<String, dynamic>>[]),
    );
    await tester.pumpWidget(MaterialApp(
      home: OfflineRecitationPage(manifestForTests: locked),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Offline Quran Recitation'), findsOneWidget);
    expect(find.text('Offline recitation is being prepared'), findsOneWidget);
    expect(find.textContaining('No recordings are enabled yet'),
        findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
}
