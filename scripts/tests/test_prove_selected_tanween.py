import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prove_selected_tanween import count_exact_and_insertions, verify_selected, IntegrityError

class SelectedTanweenContentTests(unittest.TestCase):
    def test_one_reading_copy_includes_both_small_meems_without_transformation(self):
        source = {(1,1): "بِسْم", (1,2): "الْحَمْدُ"}
        saved = dict(source)
        selected = {(1,1): "بِ\u06edسْ\u06e2م", (1,2): "الْحَمْدُ"}
        counts = count_exact_and_insertions(source, selected)
        self.assertEqual(counts["exact_verses"], 1)
        self.assertEqual(counts["small_meem_insertions_only_verses"], 1)
        self.assertEqual(counts["added_small_meem_codepoints"],
                         {"U+06E2": 1, "U+06ED": 1})
        self.assertEqual(source, saved)

    def test_any_changed_base_letter_is_rejected(self):
        with self.assertRaises(IntegrityError):
            count_exact_and_insertions({(1,1): "بِسْم"},
                                       {(1,1): "بِسْمَت"})

    def test_deleted_marker_is_rejected(self):
        with self.assertRaises(IntegrityError):
            count_exact_and_insertions({(1,1): "ب\u06edس"},
                                       {(1,1): "بس"})

    def test_missing_or_reordered_verse_is_rejected(self):
        with self.assertRaises(IntegrityError):
            count_exact_and_insertions({(1,1): "ب", (1,2): "س"},
                                       {(1,2): "س", (1,1): "ب"})

    def test_malformed_approval_selection_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp)/"selection.json"
            config.write_text(json.dumps({
                "status":"APPROVED", "sequential_tanween":"on",
                "reader_activation_enabled":True,
                "public_release_allowed":True,
                "scholarly_review":"PENDING"}), encoding="utf-8")
            with self.assertRaises(IntegrityError):
                verify_selected(Path(temp)/"nonexistent.txt", config)

    def test_wrong_source_hash_is_rejected_without_mutating_input(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root/"download.txt"
            path.write_bytes(b"not an original Quran download")
            config = root/"selection.json"
            config.write_text(json.dumps({
                "status":"INTENDED_NOT_APPROVED",
                "sequential_tanween":"on",
                "reader_activation_enabled":False,
                "public_release_allowed":False,
                "scholarly_review":"PENDING",
                "selected_original_file_sha256":"0"*64,
                "declared_export_options":{
                    "marks":"unknown","sajdah":"unknown","rub":"unknown",
                    "tatweel":"unknown","stanween":"on"
                }
            }),encoding="utf-8")
            with self.assertRaises(IntegrityError):
                verify_selected(path,config)
            self.assertEqual(path.read_bytes(),b"not an original Quran download")

if __name__ == "__main__":
    unittest.main()
