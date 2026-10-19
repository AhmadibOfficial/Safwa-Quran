import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from prepare_tanween_review_handoff import split_review_cases, IntegrityError

class ScholarlyHandoffRosterTests(unittest.TestCase):
    def test_distinct_spacing_and_recitation_sign_cases(self):
        analysis={
            "categories":{"spacing_changes_need_manual_review":1,
                          "other_unicode_differences_unresolved":1,
                          "unicode_letter_changes_unresolved":0},
            "spacing_case_diagnostics":[{
                "reference":"1:1","classification":"spacing_changes_need_manual_review",
                "older_original_verbatim":"ب \u06de س","new_original_verbatim":"ب س"
            }],
            "unresolved_case_diagnostics":[{
                "reference":"18:1","classification":"other_unicode_differences_unresolved",
                "older_original_verbatim":"عۜ ج","new_original_verbatim":"ع ج"
            }]
        }
        spacing,priority,other=split_review_cases(analysis)
        self.assertEqual([x["reference"] for x in spacing],["1:1"])
        self.assertEqual([x["reference"] for x in priority],["18:1"])
        self.assertEqual(len(other),0)

    def test_no_special_mark_removal_is_other_unresolved(self):
        a={"categories":{"spacing_changes_need_manual_review":0,
                          "other_unicode_differences_unresolved":1,
                          "unicode_letter_changes_unresolved":0},
           "spacing_case_diagnostics":[],
           "unresolved_case_diagnostics":[{"reference":"1:1",
                 "older_original_verbatim":"بِس","new_original_verbatim":"بس"}]}
        self.assertEqual(len(split_review_cases(a)[2]),1)

    def test_missing_spacing_pair_fails_closed(self):
        a={"categories":{"spacing_changes_need_manual_review":1,
                         "other_unicode_differences_unresolved":0,
                         "unicode_letter_changes_unresolved":0},
           "spacing_case_diagnostics":[],
           "unresolved_case_diagnostics":[]}
        with self.assertRaises(IntegrityError):split_review_cases(a)

    def test_duplicate_reference_fails_closed(self):
        sample={"reference":"1:1","older_original_verbatim":"بۜس",
                "new_original_verbatim":"بس"}
        a={"categories":{"spacing_changes_need_manual_review":1,
                         "other_unicode_differences_unresolved":1,
                         "unicode_letter_changes_unresolved":0},
           "spacing_case_diagnostics":[sample],
           "unresolved_case_diagnostics":[sample]}
        with self.assertRaises(IntegrityError):split_review_cases(a)

if __name__=="__main__":unittest.main()
