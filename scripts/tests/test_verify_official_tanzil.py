import sys
import tempfile
from pathlib import Path
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_official_tanzil import read_official_export, require_downloaded_file, IntegrityError

NOTICE = ("# Tanzil Quran Text (Uthmani, Version 1.1)\n"
          "# Copyright (C) Tanzil Project\n"
          "# License: Creative Commons Attribution 3.0\n"
          "# CHANGING IT IS NOT ALLOWED\n")

class OfficialTextComparisonTests(unittest.TestCase):
    def test_numbered_export_preserves_arabic(self):
        raw=("1|1|اَ\n1|2|بَ\n"+NOTICE).encode()
        parsed,kind=read_official_export(raw,[(1,1),(1,2)])
        self.assertEqual(kind,"txt-2")
        self.assertEqual(parsed[(1,2)],"بَ")

    def test_unnumbered_export_preserves_arabic(self):
        parsed,kind=read_official_export(("اَ\nبَ\n"+NOTICE).encode(),[(1,1),(1,2)])
        self.assertEqual(kind,"txt")
        self.assertEqual(parsed[(1,1)],"اَ")

    def test_missing_source_license_fails_closed(self):
        with self.assertRaises(IntegrityError):
            read_official_export("1|1|اَ\n".encode(),[(1,1)])

    def test_mixed_export_types_fails_closed(self):
        with self.assertRaises(IntegrityError):
            read_official_export(("1|1|اَ\nبَ\n"+NOTICE).encode(),[(1,1),(1,2)])

    def test_wrong_verse_reference_fails_closed(self):
        with self.assertRaises(IntegrityError):
            read_official_export(("1|2|اَ\n1|1|بَ\n"+NOTICE).encode(),[(1,1),(1,2)])

    def test_missing_official_download_produces_actionable_diagnostic(self):
        with tempfile.TemporaryDirectory() as d:
            missing = Path(d) / "tanzil-official-uthmani.txt"
            with self.assertRaisesRegex(IntegrityError, "Download the original Uthmani"):
                require_downloaded_file(missing)
            self.assertFalse(missing.exists())

    def test_existing_official_candidate_path_is_used_without_modification(self):
        with tempfile.TemporaryDirectory() as d:
            candidate = Path(d) / "official.txt"
            original = b"do-not-change"
            candidate.write_bytes(original)
            self.assertEqual(require_downloaded_file(candidate), candidate.resolve())
            self.assertEqual(candidate.read_bytes(), original)

    def test_wrong_verse_count_fails_closed(self):
        with self.assertRaises(IntegrityError):
            read_official_export(("1|1|اَ\n"+NOTICE).encode(),[(1,1),(1,2)])

if __name__=="__main__":
    unittest.main()
