import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from official_unicode_diagnostics import inspect_strings, skeleton, IntegrityError

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
