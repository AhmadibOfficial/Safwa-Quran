import csv
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_review_pack import build, IntegrityError
from validate_review_handoff import check, inspect_pack, check_submission, COLUMNS

class ReviewHandoffTests(unittest.TestCase):
    def test_valid_unapproved_package_is_reproducible(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"pack"
            build(folder)
            result=check(folder)
            self.assertEqual(result["verses_under_comparison"],308)
            self.assertEqual(result["package_integrity"],"MATCHED")
            self.assertFalse(result["reader_activation_permitted"])

    def test_report_digest_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"pack"
            build(folder)
            (folder/"index.html").write_text("corrupt",encoding="utf-8")
            with self.assertRaises(IntegrityError):
                inspect_pack(folder)

    def test_blank_template_cannot_pass_as_submission(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"pack"
            manifest=build(folder)
            with self.assertRaises(IntegrityError):
                check_submission(folder/"reviewer_1_worksheet.csv",manifest["reference_list"],manifest["primary_sha256"])

    def test_no_same_file_or_template_as_two_reviews(self):
        with tempfile.TemporaryDirectory() as root:
            folder=Path(root)/"pack"
            build(folder)
            template=folder/"reviewer_1_worksheet.csv"
            with self.assertRaises(IntegrityError):
                check(folder,template,template)

    def test_wrong_source_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            file=Path(root)/"submitted.csv"
            with file.open("w",encoding="utf-8",newline="") as fh:
                writer=csv.DictWriter(fh,fieldnames=COLUMNS)
                writer.writeheader()
                writer.writerow({"reference":"2:4","reviewer_identifier":"Reviewer A",
                    "reviewed_primary_sha256":"0"*64,
                    "official_tanzil_export_checked":"yes",
                    "unicode_difference_assessment":"Unicode detail",
                    "reference_evidence":"An independently verifiable reference",
                    "review_completed_utc":"2026-10-18T21:00:00+01:00"})
            with self.assertRaises(IntegrityError):
                check_submission(file,["2:4"],"1"*64)

if __name__=="__main__":unittest.main()
