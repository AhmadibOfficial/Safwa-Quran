import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_review_pack import codepoints, edit_operations, make_rows, build_html, IntegrityError


class ReviewPackTests(unittest.TestCase):
    def test_codepoints_record_distinct_unicode_chars(self):
        points = codepoints("اـ")
        self.assertEqual([x["codepoint"] for x in points], ["U+0627", "U+0640"])

    def test_differences_are_diagnostic_not_modifications(self):
        a = "أُوحِي"
        b = "اُوحِي"
        edits = edit_operations(a, b)
        self.assertTrue(edits)
        self.assertEqual(a, "أُوحِي")

    def test_duplicate_review_pair_rejected(self):
        first = {(1, 1): "سلام"}
        second = {(1, 1): "سـلام"}
        with self.assertRaises(IntegrityError):
            make_rows(first, second, ["1:1"])

    def test_static_html_escapes_untrusted_content(self):
        row = {"reference": "1:1", "primary": '<img src=x onerror=alert(1)>',
               "secondary": "ٱلْحَمْدُ", "unicode_operations": []}
        report = build_html([row], {"remaining_count": 1}, "license")
        self.assertNotIn('<img src=x onerror=alert(1)>', report)
        self.assertIn("&lt;img", report)
        self.assertIn("NOT VERIFIED OR APPROVED", report)

    def test_review_queue_retains_original_text(self):
        first = {(1, 1): "بِسْمِ"}
        second = {(1, 1): "بِسْم"}
        queue = make_rows(first, second, ["1:1"])
        self.assertEqual(queue[0]["primary"], first[(1, 1)])
        self.assertEqual(queue[0]["secondary"], second[(1, 1)])
        self.assertTrue(queue[0]["unicode_operations"])


if __name__ == "__main__":
    unittest.main()
