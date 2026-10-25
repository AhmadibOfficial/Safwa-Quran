"""SAFWA-016: strictly reject premature recitation manifests."""
import unittest

from scripts.check_offline_audio import assert_locked_manifest, check


class OfflineAudioGateTests(unittest.TestCase):
    def test_repo_remains_audio_locked(self):
        self.assertTrue(check())

    def test_release_manifest_cannot_claim_approval(self):
        with self.assertRaises(ValueError):
            assert_locked_manifest({
                "format": "safwa-offline-recitation",
                "schema": 1, "status": "REVIEW_ONLY", "tracks": [],
            })

    def test_locked_release_cannot_contain_recordings(self):
        with self.assertRaises(ValueError):
            assert_locked_manifest({
                "format": "safwa-offline-recitation",
                "schema": 1, "status": "LOCKED",
                "tracks": [{"surah": 1, "file_name": "001.mp3"}],
            })


if __name__ == "__main__":
    unittest.main()
