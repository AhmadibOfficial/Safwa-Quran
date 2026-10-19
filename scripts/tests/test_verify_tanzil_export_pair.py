import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_tanzil_export_pair import compare_pair_maps, validate_settings, IntegrityError

class PairedTanzilExportsTests(unittest.TestCase):
    def test_small_meems_only_between_controlled_exports(self):
        off = {(1, 1): "بِسْم", (1, 2): "الْحَمْدُ"}
        on = {(1, 1): "بِ\u06EDسْ\u06E2م", (1, 2): "الْحَمْدُ"}
        old = dict(off)
        result = compare_pair_maps(off, on)
        self.assertTrue(result["only_small_meem_insertions_observed"])
        self.assertEqual(result["off_to_on_small_meem_insertions_only"], 1)
        self.assertEqual(result["inserted_small_meem_counts"]["U+06ED"], 1)
        self.assertEqual(result["inserted_small_meem_counts"]["U+06E2"], 1)
        self.assertEqual(off, old)

    def test_unexplained_letter_insertions_fail_hypothesis(self):
        result = compare_pair_maps({(1, 1): "بِسْم"}, {(1, 1): "بِسْمِن"})
        self.assertFalse(result["only_small_meem_insertions_observed"])
        self.assertEqual(result["other_export_pair_references"], ["1:1"])

    def test_removed_mark_not_counted_as_small_meem_addition(self):
        result = compare_pair_maps({(1, 1): "ب\u06EDس"}, {(1, 1): "بس"})
        self.assertFalse(result["only_small_meem_insertions_observed"])

    def test_identical_maps_do_not_prove_setting_toggle(self):
        result = compare_pair_maps({(1, 1): "ب"}, {(1, 1): "ب"})
        self.assertFalse(result["only_small_meem_insertions_observed"])

    def test_reference_order_mismatch_fails_closed(self):
        with self.assertRaises(IntegrityError):
            compare_pair_maps({(1, 1): "ب", (1, 2): "س"},
                              {(1, 2): "س", (1, 1): "ب"})

    def test_empty_pair_fails_closed(self):
        with self.assertRaises(IntegrityError):
            compare_pair_maps({}, {})

    def test_all_four_common_settings_must_be_recorded(self):
        values = {"marks":"on", "sajdah":"off", "rub":"on", "tatweel":"off"}
        self.assertTrue(validate_settings(values))
        self.assertFalse(validate_settings(dict(values, marks="unknown")))
        with self.assertRaises(IntegrityError):
            validate_settings({"marks":"on"})

if __name__ == "__main__":
    unittest.main()
