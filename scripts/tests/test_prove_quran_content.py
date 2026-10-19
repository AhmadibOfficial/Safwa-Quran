import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from prove_quran_content import content_digest, IntegrityError

class ContentProofTests(unittest.TestCase):
    def test_reproducible_indexed_digest(self):
        a={(1,1):"بِسْمِ", (1,2):"الرَّحْمَٰن"}
        b=dict(a)
        self.assertEqual(content_digest(a),content_digest(b))

    def test_single_codepoint_change_changes_content_hash(self):
        a={(1,1):"بِسْمِ"}
        b={(1,1):"بِسْم"}
        self.assertNotEqual(content_digest(a),content_digest(b))

    def test_reference_change_changes_content_hash(self):
        a={(1,1):"سلام"}
        b={(1,2):"سلام"}
        self.assertNotEqual(content_digest(a),content_digest(b))

    def test_no_implicit_unicode_normalization(self):
        one={(1,1):"\u0622"}
        two={(1,1):"\u0627\u0653"}
        self.assertNotEqual(content_digest(one),content_digest(two))

    def test_empty_and_multiline_verses_rejected(self):
        with self.assertRaises(IntegrityError): content_digest({})
        with self.assertRaises(IntegrityError): content_digest({(1,1):"ب\nس"})
        with self.assertRaises(IntegrityError): content_digest({(1,1):""})

if __name__=="__main__":
    unittest.main()
