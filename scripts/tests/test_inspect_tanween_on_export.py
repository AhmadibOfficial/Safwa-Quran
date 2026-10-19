import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from inspect_tanween_on_export import (
    EXPECTED_REMOVABLE, deletion_of_only_allowed, examine_pair, IntegrityError,
)

class ExportForensicTests(unittest.TestCase):
    def test_only_tatweel_deletion(self):
        # Remove exactly U+0640 TATWEEL, preserving U+0652 SUKUN.
        a = {(1,1): "بِسْـم"}
        b = {(1,1): "بِسْم"}
        result = examine_pair(a,b)
        self.assertEqual(result["categories"]["listed_annotation_deletions_only"], 1)
        self.assertEqual(result["categories"]["unicode_letter_changes_unresolved"], 0)

    def test_sequential_tanween_meem_must_not_be_deleted(self):
        self.assertNotIn("\u06ed", EXPECTED_REMOVABLE)
        self.assertNotIn("\u06e2", EXPECTED_REMOVABLE)
        self.assertFalse(deletion_of_only_allowed("ب\u06edس", "بس"))

    def test_optional_sign_and_its_space_deletion_is_separately_flagged(self):
        a={(1,1): "ب \u06de س"}
        b={(1,1): "ب س"}
        r=examine_pair(a,b)
        self.assertEqual(r["categories"]["spacing_changes_need_manual_review"],1)

    def test_base_letter_removal_is_unresolved(self):
        r=examine_pair({(1,1):"بسم"}, {(1,1):"بم"})
        self.assertEqual(r["categories"]["unicode_letter_changes_unresolved"],1)

    def test_unauthorized_diacritic_loss_is_unresolved(self):
        r=examine_pair({(1,1):"بِس"}, {(1,1):"بس"})
        self.assertEqual(r["categories"]["other_unicode_differences_unresolved"],1)

    def test_removed_sukun_cannot_be_excused_as_tatweel(self):
        r=examine_pair({(1,1):"بِسْـم"}, {(1,1):"بِسم"})
        self.assertEqual(r["categories"]["other_unicode_differences_unresolved"],1)
        self.assertEqual(r["unresolved_case_diagnostics"][0]["removed_codepoints"],
                         ["U+0640","U+0652"])

    def test_unlisted_small_high_seen_requires_manual_review(self):
        r=examine_pair({(1,1):"ب\u06dcس"}, {(1,1):"بس"})
        self.assertEqual(r["categories"]["other_unicode_differences_unresolved"],1)
        self.assertEqual(r["unresolved_case_diagnostics"][0]["reference"],"1:1")
        self.assertEqual(r["unresolved_case_diagnostics"][0]["removed_codepoints"],
                         ["U+06DC"])

    def test_order_and_empty_maps_fail_closed(self):
        with self.assertRaises(IntegrityError):
            examine_pair({(1,1):"ب",(1,2):"س"}, {(1,2):"س",(1,1):"ب"})
        with self.assertRaises(IntegrityError):
            examine_pair({}, {})

    def test_no_source_mutation(self):
        older={(1,1): "ب \u06de س"}
        new={(1,1): "ب س"}
        saved=(dict(older),dict(new))
        examine_pair(older,new)
        self.assertEqual((older,new),saved)

    def test_matching_strings_are_exact(self):
        d=examine_pair({(1,1):"بِسم"}, {(1,1):"بِسم"})
        self.assertEqual(d["categories"]["exact"],1)

if __name__=="__main__": unittest.main()
