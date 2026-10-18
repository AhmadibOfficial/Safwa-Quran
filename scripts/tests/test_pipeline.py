import json
import tempfile
import unittest
from pathlib import Path
import sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import quran_pipeline as p

class SafwaPipelineTests(unittest.TestCase):
    def test_catalog(self):
        self.assertEqual(len(p.catalog()),114)
        self.assertEqual(sum(row[2] for row in p.catalog()),6236)
    def test_locked_release(self):
        with self.assertRaisesRegex(p.IntegrityError,"Release blocked"):
            p.release_check()
    def test_development_safe(self):
        self.assertTrue(p.check())
    def test_duplicate_chapter_rejected(self):
        with self.assertRaises(p.IntegrityError):
            p.validate_chapters([{"number":1,"verses":[]}]*114,p.catalog())
    def test_missing_verse_rejected(self):
        with self.assertRaises(p.IntegrityError):
            p.validate_chapters([{"number":n,"verses":[]} for n in range(1,115)],p.catalog())
    def test_bad_activation_fails_closed(self):
        original=p.ACT
        with tempfile.TemporaryDirectory() as d:
            p.ACT=Path(d)/"activation.json"
            p.ACT.write_text(json.dumps({"quran_reader_enabled":True,"review_status":"pending"}))
            try:
                with self.assertRaisesRegex(p.IntegrityError,"Unreviewed"):
                    p.check()
            finally:p.ACT=original
if __name__=="__main__":unittest.main()
