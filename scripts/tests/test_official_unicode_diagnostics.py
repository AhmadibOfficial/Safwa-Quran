import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from official_unicode_diagnostics import inspect_strings, skeleton, only_added_small_meems, IntegrityError

class OfficialUnicodeDiagnosticsTests(unittest.TestCase):
    def test_only_comparison_skeleton_drops_marks_not_original(self):
        original="بِسْـمِ"
        self.assertEqual(skeleton(original),"بسم")
        self.assertEqual(original,"بِسْـمِ")

    def test_diagnostic_categories_preserve_verse_strings(self):
        pinned={(1,1):"نصر", (1,2):"اِسـم", (1,3):"بِسْم", (1,4):"سَمْع"}
        copied=dict(pinned)
        candidate={(1,1):"نصر", (1,2):"اِسم", (1,3):"بسم", (1,4):"مَعْن"}
        report=inspect_strings(pinned,candidate)
        self.assertEqual([report[k] for k in (
            "exact", "tatweel_only_diagnostic", "marks_or_tatweel_diagnostic",
            "other_string_differences")],[1,1,1,1])
        self.assertEqual(pinned,copied)
        self.assertEqual(report["verse_count"],4)
        self.assertEqual(len(report["representative_unmodified_pairs"]),3)

    def test_me_quran_small_meems_are_identified_without_modifying_sources(self):
        pinned = {(1, 1): "بِسْم"}
        original = dict(pinned)
        downloaded = {(1, 1): "بِ\u06EDسْ\u06E2م"}
        result = inspect_strings(pinned, downloaded)
        self.assertEqual(result["optional_small_meem_insertions_diagnostic"], 1)
        self.assertEqual(result["marks_or_tatweel_diagnostic"], 0)
        self.assertEqual(result["other_string_differences"], 0)
        self.assertEqual(result["representative_unmodified_pairs"][0]["download_verbatim"],
                         downloaded[(1, 1)])
        self.assertEqual(pinned, original)

    def test_existing_small_meem_in_pinned_is_preserved(self):
        self.assertTrue(only_added_small_meems("ب\u06E2ت", "ب\u06E2\u06EDت"))

    def test_non_marker_insertion_is_not_misclassified(self):
        report = inspect_strings({(1, 1): "بِسْم"}, {(1, 1): "بِسْم\u06EDن"})
        self.assertEqual(report["optional_small_meem_insertions_diagnostic"], 0)
        self.assertEqual(report["other_string_differences"], 1)

    def test_marker_removed_from_candidate_is_not_marker_addition(self):
        report = inspect_strings({(1, 1): "ب\u06EDس"}, {(1, 1): "بس"})
        self.assertEqual(report["optional_small_meem_insertions_diagnostic"], 0)
        self.assertEqual(report["marks_or_tatweel_diagnostic"], 1)

    def test_wrong_order_fails_closed(self):
        with self.assertRaises(IntegrityError):
            inspect_strings({(1,1):"ب", (1,2):"ا"},{(1,2):"ا", (1,1):"ب"})

    def test_sample_count_limit_and_unicode_reporting(self):
        report=inspect_strings({(1,1):"سـلام", (1,2):"بِسْم"},
                               {(1,1):"سلام", (1,2):"بسم"},sample_limit=1)
        self.assertEqual(len(report["representative_unmodified_pairs"]),1)
        self.assertIn("U+0640",[x["codepoint"] for x in report["most_removed_codepoints"]])

    def test_invalid_sample_limit_is_rejected(self):
        with self.assertRaises(IntegrityError):
            inspect_strings({(1,1):"ب"},{(1,1):"ا"},-1)

if __name__ == "__main__":
    unittest.main()
