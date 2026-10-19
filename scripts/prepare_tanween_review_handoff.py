#!/usr/bin/env python3
"""Prepare an integrity-bound OFF/ON-option Quran review handoff, not approval.

All original Arabic input remains read-only. Output is ignored under .staging.
Entire 6236-verse selected candidate is included for TWO genuine independent
qualified Quran reviewers; high-risk omissions are highlighted, not accepted.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

from compare_uthmani_editions import IntegrityError, parse_primary
from build_review_pack import SOURCE_A
from inspect_tanween_on_export import inspect_files, OLD_SHA, NEW_SHA
from verify_official_tanzil import read_official_export

ROOT = Path(__file__).resolve().parents[1]
REVIEW_CATEGORY = "spacing_changes_need_manual_review"
SMALL_SEEN = "\u06dc"
COPYRIGHT_MARKER = "# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK"


def split_review_cases(analysis):
    """Never conflate spacing issues with deleted recitation marks."""
    categories = analysis["categories"]
    spacing = list(analysis["spacing_case_diagnostics"])
    unresolved = list(analysis["unresolved_case_diagnostics"])
    if (len(spacing) != categories["spacing_changes_need_manual_review"] or
        len(unresolved) != categories["unicode_letter_changes_unresolved"]
                          + categories["other_unicode_differences_unresolved"]):
        raise IntegrityError("Review data is incomplete; refuse partial handoff")
    seen = set()
    for item in spacing + unresolved:
        ref = item["reference"]
        if ref in seen:
            raise IntegrityError("Review case duplicated: "+ref)
        seen.add(ref)
    saktah = [item for item in unresolved if
              item["older_original_verbatim"].count(SMALL_SEEN) >
              item["new_original_verbatim"].count(SMALL_SEEN)]
    remaining = [item for item in unresolved if item not in saktah]
    return spacing, saktah, remaining


def write_csv(path, headers, rows):
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=headers)
        writer.writeheader()
        for record in rows:
            writer.writerow({key: record.get(key, "") for key in headers})


def build(old_path, new_path, out_dir):
    # Real source audit: SHA-pinned files, full surah catalog, copyright, and
    # complete reference order are checked by inspect_files before output.
    report = inspect_files(old_path, new_path, sample_limit=0)
    analysis = report["analysis"]
    spacing, saktah, remaining = split_review_cases(analysis)
    original = parse_primary(SOURCE_A.read_bytes())
    selected, fmt = read_official_export(Path(new_path).expanduser().read_bytes(),
                                          list(original))
    if len(selected) != 6236 or fmt != "txt-2":
        raise IntegrityError("Full selected numbered Quran corpus required")
    if len(spacing) + len(saktah) + len(remaining) != (
        analysis["categories"]["spacing_changes_need_manual_review"] +
        analysis["categories"]["other_unicode_differences_unresolved"] +
        analysis["categories"]["unicode_letter_changes_unresolved"]
    ):
        raise IntegrityError("Unexpected case exclusion")
    if (hashlib.sha256(Path(old_path).expanduser().read_bytes()).hexdigest() != OLD_SHA or
        hashlib.sha256(Path(new_path).expanduser().read_bytes()).hexdigest() != NEW_SHA):
        raise IntegrityError("Source files changed after audit")
    text = Path(new_path).expanduser().read_text(encoding="utf-8-sig")
    if COPYRIGHT_MARKER not in text:
        raise IntegrityError("Original Tanzil copyright notice missing")
    notice = text[text.index(COPYRIGHT_MARKER):]

    staging = (ROOT / ".staging").resolve()
    output = out_dir.resolve()
    if not output.is_relative_to(staging):
        raise IntegrityError("Private review handoff must remain in .staging")
    if output.exists() and any(output.iterdir()):
        raise IntegrityError("Refusing to overwrite previously generated or completed reviewer work")
    output.mkdir(parents=True, exist_ok=True)

    full = output/"selected_complete_corpus.csv"
    write_csv(full, ("reference","selected_verse_verbatim"),
              ({"reference":f"{ref[0]}:{ref[1]}",
                "selected_verse_verbatim":verse}
               for ref, verse in selected.items()))

    cases = spacing + saktah + remaining
    headers = ("reference","category","older_verse_verbatim",
               "new_verse_verbatim","removed_space_count","added_space_count",
               "removed_codepoints","added_codepoints")
    def to_row(entry):
        return {
            "reference":entry["reference"],"category":entry["classification"],
            "older_verse_verbatim":entry["older_original_verbatim"],
            "new_verse_verbatim":entry["new_original_verbatim"],
            "removed_space_count":entry.get("removed_space_count",""),
            "added_space_count":entry.get("added_space_count",""),
            "removed_codepoints":",".join(entry.get("removed_codepoints",[])),
            "added_codepoints":",".join(entry.get("added_codepoints",[])),
        }
    write_csv(output/"all_flagged_cases.csv",headers,(to_row(e) for e in cases))
    write_csv(output/"spacing_cases.csv",headers,(to_row(e) for e in spacing))
    write_csv(output/"small_seen_cases.csv",headers,(to_row(e) for e in saktah))
    write_csv(output/"other_unresolved_cases.csv",headers,(to_row(e) for e in remaining))
    (output/"tanzil_copyright_notice.txt").write_text(notice,encoding="utf-8")
    # Blank forms must not be interpreted as scholarly approvals.
    attestation_headers=("reference","reviewer_identity","quran_qualification_evidence",
      "intended_on_content_sha256","authoritative_hafs_mushaf_reference",
      "arabic_text_and_mark_assessment","recitation_and_spacing_assessment",
      "supporting_evidence","reviewed_utc","reviewer_signature")
    for number in (1,2):
        write_csv(output/f"reviewer_{number}_blank_worksheet.csv",
            attestation_headers,
            ({"reference":f"{ref[0]}:{ref[1]}"} for ref in selected))
    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    artifacts = sorted(path for path in output.iterdir() if path.is_file())
    manifest={
      "status":"UNAPPROVED_REVIEW_HANDOFF",
      "source_description":"Single candidate Uthmani v1.1, user-declared tanween ON; other four options OFF",
      "selected_candidate_original_sha256":NEW_SHA,
      "comparison_reference_original_sha256":OLD_SHA,
      "selected_ordered_verse_sha256":report["new_on_ordered_verse_content_sha256"],
      "complete_verse_count":len(selected),
      "strictly_flagged_case_count":len(cases),
      "spacing_cases_unapproved":len(spacing),
      "small_seen_cases_high_priority":len(saktah),
      "other_unresolved_cases":len(remaining),
      "reviewer_count_authenticated":0,
      "font_rights_and_rendering_verified":False,
      "official_provenance_authenticated":False,
      "all_verses_scholarly_approved":False,
      "reader_activation_allowed":False,
      "public_release_allowed":False,
      "files_sha256":{file.name:sha(file) for file in artifacts},
      "warning":"Generated files are incomplete human-review evidence, never Quran authentication or approval."
    }
    (output/"manifest.json").write_text(
        json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return manifest


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--old-on",required=True,type=Path)
    ap.add_argument("--new-on",required=True,type=Path)
    ap.add_argument("--out-dir",type=Path,default=Path(
        ".staging/selected-on-scholarly-review-2026-10-19"))
    args=ap.parse_args()
    try:
        report=build(args.old_on,args.new_on,args.out_dir)
        print(json.dumps({
         "status":report["status"],
         "selected_candidate_original_sha256":report["selected_candidate_original_sha256"],
         "selected_ordered_verse_sha256":report["selected_ordered_verse_sha256"],
         "complete_verse_count":report["complete_verse_count"],
         "spacing_cases_unapproved":report["spacing_cases_unapproved"],
         "small_seen_cases_high_priority":report["small_seen_cases_high_priority"],
         "other_unresolved_cases":report["other_unresolved_cases"],
         "private_directory":str(args.out_dir.resolve()),
         "scholarly_approval":"PENDING","release":"BLOCKED"
        },ensure_ascii=False,indent=2))
        return 0
    except (OSError,ValueError,KeyError,TypeError,UnicodeError) as error:
        print("FAIL: "+str(error),file=sys.stderr)
        return 1

if __name__=="__main__":
    sys.exit(main())
