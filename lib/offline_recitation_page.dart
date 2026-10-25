import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'offline_recitation.dart';

/// SAFWA-016: public-safe discoverability screen. Audio playback remains
/// disabled until redistribution rights and independent reviews are approved.
class OfflineRecitationPage extends StatelessWidget {
  const OfflineRecitationPage({super.key, this.manifestForTests});

  final OfflineRecitationManifest? manifestForTests;

  Future<OfflineRecitationManifest> _manifest() async {
    final supplied = manifestForTests;
    if (supplied != null) return supplied;
    final text = await rootBundle.loadString(
      'assets/data/offline_recitation_manifest.json',
    );
    return OfflineRecitationManifest.parse(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Quran Recitation')),
      body: FutureBuilder<OfflineRecitationManifest>(
        future: _manifest(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Offline recitation manifest could not be verified. '
                'Audio playback remains disabled.',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // This release build NEVER creates a media player, even if someone
          // modifies the manifest to carry review-only track descriptors.
          return const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones_outlined, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'Offline recitation is being prepared',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No recordings are enabled yet. Each recitation must '
                      'have confirmed redistribution rights, verified '
                      'audio files and independent review before release. '
                      'Offline listening will never require streaming.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
