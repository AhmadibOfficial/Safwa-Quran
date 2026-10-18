#!/usr/bin/env python3
"""Compare an independently obtained Tanzil export OFFLINE without editing it.

A source URL or filename alone does not prove that the file came from Tanzil.
No output from this script constitutes religious certification or app activation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from compare_uthmani_editions import IntegrityError, PRIMARY_SHA, git_sha, parse_primary
from build_review_pack import SOURCE_A, CATALOG

NOTICE = ("tanzil quran text", "creative commons attribution", "changing it is not allowed")
ARABIC = re.compile(r"[\u0600-\u06ff]")
REFERENCE_LINE = re.compile(r"^([0-9]+)\|([0-9]+)\|(.+)$")
ALLOWED_OPTIONS = {"on", "off", "unknown"}

def read_official_export(raw, ordered_refs):
    """Parse plain verses or surah|ayah|text export. Preserve every character."""
    original = raw.decode("utf-8-sig")
    lowered = original.casefold()
    if any(term not in lowered for term in NOTICE):
        raise IntegrityError("Download lacks recognizable Tanzil attribution and verbatim-copy notice")
    lines = [line for line in original.splitlines() if line and not line.startswith("#")]
    if len(lines) != len(ordered_refs):
        raise IntegrityError("Expected exactly 6,236 ayah records; no changes can be inferred")
    indexed = bool(REFERENCE_LINE.fullmatch(lines[0]))
    result = {}
    for i, line in enumerate(lines):
        expected = ordered_refs[i]
        if indexed:
            match = REFERENCE_LINE.fullmatch(line)
            if not match:
                raise IntegrityError("Mixed numbered/unnumbered Quran text format")
            key = (int(match.group(1)), int(match.group(2)))
            verse = match.group(3)
            if key != expected:
                raise IntegrityError("Official candidate ayah references out of sequence")
        else:
            if REFERENCE_LINE.fullmatch(line) or "|" in line:
                raise IntegrityError("Mixed Quran text format")
            key = expected
            verse = line
        if not verse or not ARABIC.search(verse):
            raise IntegrityError("Empty or non-Arabic Quran verse encountered")
        result[key] = verse
    return result, "txt-2" if indexed else "txt"

def analyze(official_file, declared_options, pinned_file=SOURCE_A, catalog=CATALOG):
    if set(declared_options) != {"marks","sajdah","rub","tatweel","stanween"}:
        raise IntegrityError("Specify all five Tanzil export-option settings")
    if any(option not in ALLOWED_OPTIONS for option in declared_options.values()):
        raise IntegrityError("Export options must be on, off or unknown")
    canonical_raw = pinned_file.read_bytes()
    if git_sha(canonical_raw) != PRIMARY_SHA:
        raise IntegrityError("Reference Quran Git object changed")
    chapters = [row.split("|") for row in catalog.read_text(encoding="utf-8").splitlines() if row]
    expected = [(int(s[0]),n) for s in chapters for n in range(1,int(s[2])+1)]
    reference = parse_primary(canonical_raw)
    if len(chapters) != 114 or len(expected) != 6236 or list(reference) != expected:
        raise IntegrityError("Reference Quran catalog does not contain 6,236 ordered ayahs")
    original = official_file.read_bytes()
    official, fmt = read_official_export(original, expected)
    exact = 0
    tatweel_only = 0
    pending = []
    for key in expected:
        first, second = reference[key], official[key]
        if first == second:
            exact += 1
        elif first.replace("\u0640","") == second.replace("\u0640",""):
            tatweel_only += 1
        else:
            pending.append(f"{key[0]}:{key[1]}")
    return {
        "status": "OFFICIAL_EXPORT_CANDIDATE_NOT_AUTHENTICATED",
        "download_source_claim": "https://tanzil.net/download",
        "provenance_note": "The operator must independently document that these bytes came from the official site.",
        "official_input_format":fmt,
        "declared_export_options":declared_options,
        "export_options_have_unknown_values":"unknown" in declared_options.values(),
        "pinned_source_git_blob_sha1": PRIMARY_SHA,
        "pinned_sha256":hashlib.sha256(canonical_raw).hexdigest(),
        "downloaded_candidate_sha256":hashlib.sha256(original).hexdigest(),
        "verse_count": len(expected),
        "exact_verse_matches": exact,
        "tatweel_only_matches_diagnostic":tatweel_only,
        "other_differences_count":len(pending),
        "other_differences":pending,
        "source_text_modified":False,
        "independent_scholarly_review":"PENDING",
        "quran_reader_activation_allowed":False,
        "public_release_allowed":False,
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--official", required=True, type=Path,
                        help="Download yourself from the official Tanzil download page")
    parser.add_argument("--out",type=Path,default=Path(".staging/official_tanzil_comparison.json"))
    for key in ("marks","sajdah","rub","tatweel","stanween"):
        parser.add_argument("--"+key,choices=sorted(ALLOWED_OPTIONS),required=True)
    a=parser.parse_args()
    options={key:getattr(a,key) for key in ("marks","sajdah","rub","tatweel","stanween")}
    try:
        result=analyze(a.official,options)
        # Evidence is quarantined; never write comparison output into Flutter assets.
        target=a.out.resolve()
        quarantine=(Path(__file__).resolve().parents[1]/".staging").resolve()
        if not target.is_relative_to(quarantine):
            raise IntegrityError("Review reports must stay in the ignored .staging directory")
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
        print(json.dumps(result,indent=2,ensure_ascii=False))
        return 0
    except (OSError,UnicodeError,ValueError,KeyError,TypeError) as err:
        print("FAIL: "+str(err),file=sys.stderr)
        return 1

if __name__=="__main__":
    sys.exit(main())
