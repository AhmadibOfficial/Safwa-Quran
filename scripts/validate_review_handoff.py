#!/usr/bin/env python3
"""Offline review-handoff evidence integrity, NOT religious certification."""
import argparse
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import sys

from compare_uthmani_editions import audit, IntegrityError
from build_review_pack import SOURCE_A, SOURCE_B, CATALOG

ARTIFACTS = {
    "dossier_html_sha256": "index.html",
    "dossier_csv_sha256": "unresolved_verses.csv",
    "reviewer_1_worksheet_sha256": "reviewer_1_worksheet.csv",
    "reviewer_2_worksheet_sha256": "reviewer_2_worksheet.csv",
}
COLUMNS = [
    "reference", "reviewer_identifier", "reviewed_primary_sha256",
    "official_tanzil_export_checked", "unicode_difference_assessment",
    "reference_evidence", "reviewer_notes", "review_completed_utc",
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def csv_rows(file, headers):
    with file.open("r", encoding="utf-8-sig", newline="") as src:
        reader = csv.DictReader(src)
        if reader.fieldnames != list(headers):
            raise IntegrityError("Incorrect CSV headers: " + str(file))
        data = list(reader)
        if any(None in row or None in row.values() for row in data):
            raise IntegrityError("Malformed CSV columns: " + str(file))
        return data

def inspect_pack(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if (manifest.get("review_status") != "UNAPPROVED" or
        manifest.get("release_allowed") is not False or
        manifest.get("reviewers") != [] or
        manifest.get("review_evidence_authenticated") is not False or
        manifest.get("official_tanzil_download_verified") is not False):
        raise IntegrityError("An unapproved pack must remain locked and unsigned")
    expected = audit(SOURCE_A, SOURCE_B, CATALOG)["remaining_references"]
    if (manifest.get("reference_list") != expected or
        manifest.get("unresolved_count") != 308 or len(expected) != 308):
        raise IntegrityError("Changed unresolved-verse roster")
    if manifest.get("primary_sha256") != sha(SOURCE_A) or manifest.get("secondary_sha256") != sha(SOURCE_B):
        raise IntegrityError("Pinned Quran source hash changed")
    for key, name in ARTIFACTS.items():
        if manifest.get(key) != sha(directory / name):
            raise IntegrityError("Review artifact digest changed: " + name)
    comparison = csv_rows(directory / "unresolved_verses.csv",
        ["reference", "primary", "secondary", "unicode_operations"])
    if [x["reference"] for x in comparison] != expected:
        raise IntegrityError("Comparison CSV references changed")
    for n in ("reviewer_1", "reviewer_2"):
        rows = csv_rows(directory / (n + "_worksheet.csv"), COLUMNS)
        if [x["reference"] for x in rows] != expected:
            raise IntegrityError("Reviewer template reference list changed")
        if any(any(v.strip() for k,v in row.items() if k != "reference") for row in rows):
            raise IntegrityError("Reviewer templates must be BLANK; save completed copies elsewhere")
    return manifest

def check_submission(path, refs, digest):
    rows = csv_rows(path, COLUMNS)
    if [x["reference"] for x in rows] != refs:
        raise IntegrityError("Submitted reviewer references do not match immutable roster")
    reviewers = {r["reviewer_identifier"].strip() for r in rows}
    if len(reviewers) != 1 or "" in reviewers:
        raise IntegrityError("Reviewer identity field must be consistent and present")
    for row in rows:
        ref = row["reference"]
        if row["reviewed_primary_sha256"].strip().lower() != digest:
            raise IntegrityError("Reviewer cited incorrect Quran SHA-256: " + ref)
        if row["official_tanzil_export_checked"].strip().lower() != "yes":
            raise IntegrityError("Official export evidence not acknowledged: " + ref)
        if not row["unicode_difference_assessment"].strip() or not row["reference_evidence"].strip():
            raise IntegrityError("Missing assessment or evidence reference: " + ref)
        try:
            date = datetime.fromisoformat(row["review_completed_utc"].strip().replace("Z","+00:00"))
            if date.utcoffset() is None:
                raise ValueError("No timezone")
        except ValueError as e:
            raise IntegrityError("Missing or invalid timezone-aware review timestamp: " + ref) from e
    return {"claimed_reviewer_identifier": next(iter(reviewers)),
            "submitted_sha256": sha(path), "rows_structurally_complete": len(rows)}

def check(directory, first=None, second=None):
    manifest=inspect_pack(directory)
    result={"status":"STRUCTURE_ONLY_NOT_RELIGIOUS_APPROVAL",
            "package_integrity":"MATCHED",
            "verses_under_comparison":manifest["unresolved_count"],
            "pinned_quran_sha256":manifest["primary_sha256"],
            "reviewer_identities_authenticated":False,
            "scholarly_approval":"PENDING",
            "reader_activation_permitted":False,
            "public_release_permitted":False}
    if (first is None) != (second is None):
        raise IntegrityError("Two separate reviewer submissions required")
    if first is not None:
        if first.resolve() == second.resolve():
            raise IntegrityError("Reviewer submissions must be distinct files")
        for path in (first,second):
            if path.resolve().is_relative_to(directory.resolve()):
                raise IntegrityError("Reviewer submission must not replace a template or dossier artifact")
        a=check_submission(first,manifest["reference_list"],manifest["primary_sha256"])
        b=check_submission(second,manifest["reference_list"],manifest["primary_sha256"])
        if a["claimed_reviewer_identifier"].casefold() == b["claimed_reviewer_identifier"].casefold():
            raise IntegrityError("Reviewer identity fields cannot be identical")
        result["unverified_reviewer_submissions"]=[a,b]
        result["submission_format"]="COMPLETE_BUT_NOT_AUTHENTICATED"
    return result

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--pack",type=Path,required=True)
    p.add_argument("--reviewer-one",type=Path)
    p.add_argument("--reviewer-two",type=Path)
    args=p.parse_args()
    try:
        result=check(args.pack,args.reviewer_one,args.reviewer_two)
    except (OSError,ValueError,KeyError,TypeError) as exc:
        p.exit(1,"FAIL: "+str(exc)+"\n")
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 0

if __name__=="__main__":sys.exit(main())
