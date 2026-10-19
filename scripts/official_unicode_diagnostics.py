#!/usr/bin/env python3
"""Offline Unicode difference dossier. Diagnostic ONLY; never approves Quran."""
import argparse
from collections import Counter
from difflib import SequenceMatcher
import hashlib
import json
from pathlib import Path
import sys
import unicodedata

from compare_uthmani_editions import IntegrityError, parse_primary
from verify_official_tanzil import (
    SOURCE_A, CATALOG, analyze, read_official_export,
    require_downloaded_file, ALLOWED_OPTIONS,
)

ROOT = Path(__file__).resolve().parents[1]
OPTION_NAMES = ("marks", "sajdah", "rub", "tatweel", "stanween")
# These characters are used in the optional me_quran sequential-tanween notation.
# Removing them is allowed ONLY in transient comparisons, NEVER in Quran assets.
ME_QURAN_SMALL_MEEMS = frozenset(("\u06ED", "\u06E2"))

def only_added_small_meems(pinned, downloaded):
    """True only if downloaded differs by INSERTIONS of the two small-meem marks.

    A left-to-right subsequence walk preserves every source character and
    refuses any removal, replacement, or addition of non-listed codepoints.
    This is not a religious equivalence check.
    """
    at = 0
    inserted = 0
    for character in downloaded:
        if at < len(pinned) and character == pinned[at]:
            at += 1
        elif character in ME_QURAN_SMALL_MEEMS:
            inserted += 1
        else:
            return False
    return at == len(pinned) and inserted > 0

def skeleton(text):
    """Only for comparing; the original Unicode strings are never replaced."""
    return "".join(c for c in text if c != "\u0640" and
                   not unicodedata.category(c).startswith("M"))

def character_report(counter, limit=30):
    return [
        {"codepoint": "U+%04X" % ord(c),
         "unicode_name": unicodedata.name(c, "UNASSIGNED"), "count": count}
        for c, count in counter.most_common(limit)
    ]

def inspect_strings(pinned, candidate, sample_limit=12):
    if sample_limit < 0 or list(pinned) != list(candidate):
        raise IntegrityError("Aligned source order required for Unicode diagnostics")
    exact = tatweel = small_meem = marks = other = 0
    removed = Counter()
    added = Counter()
    examples = []
    for ref, original in pinned.items():
        downloaded = candidate[ref]
        if original == downloaded:
            exact += 1
            continue
        if original.replace("\u0640", "") == downloaded.replace("\u0640", ""):
            tatweel += 1
            category = "tatweel_only_diagnostic"
        elif only_added_small_meems(original, downloaded):
            small_meem += 1
            category = "optional_small_meem_insertions_diagnostic"
        elif skeleton(original) == skeleton(downloaded):
            marks += 1
            category = "marks_or_tatweel_diagnostic"
        else:
            other += 1
            category = "other_string_difference"
        operations = []
        for kind, i, j, k, n in SequenceMatcher(
            None, original, downloaded, autojunk=False
        ).get_opcodes():
            if kind == "equal":
                continue
            left, right = original[i:j], downloaded[k:n]
            removed.update(left)
            added.update(right)
            operations.append({
                "kind": kind,
                "removed": ["U+%04X" % ord(c) for c in left],
                "added": ["U+%04X" % ord(c) for c in right],
            })
        if len(examples) < sample_limit:
            examples.append({
                "reference": "%s:%s" % ref,
                "classification": category,
                "pinned_verbatim": original,
                "download_verbatim": downloaded,
                "codepoint_edits": operations,
            })
    return {
        "exact": exact, "tatweel_only_diagnostic": tatweel,
        "optional_small_meem_insertions_diagnostic": small_meem,
        "marks_or_tatweel_diagnostic": marks,
        "other_string_differences": other,
        "verse_count": len(pinned),
        "most_removed_codepoints": character_report(removed),
        "most_added_codepoints": character_report(added),
        "representative_unmodified_pairs": examples,
        "warning": "These alignment categories do not establish Quranic equivalence or correctness.",
    }

def make_report(path, opts, samples=12):
    baseline = analyze(path, opts)
    original = parse_primary(SOURCE_A.read_bytes())
    downloaded, fmt = read_official_export(path.read_bytes(), list(original))
    differences = inspect_strings(original, downloaded, samples)
    if (differences["exact"] != baseline["exact_verse_matches"] or
        differences["tatweel_only_diagnostic"] != baseline["tatweel_only_matches_diagnostic"] or
        differences["optional_small_meem_insertions_diagnostic"] +
        differences["marks_or_tatweel_diagnostic"] +
        differences["other_string_differences"] != baseline["other_differences_count"]):
        raise IntegrityError("Unicode diagnostics do not match source-count audit")
    return {
        "status": "PRIVATE_DIAGNOSTIC_NOT_AUTHENTICATED",
        "source_sha256": baseline["pinned_sha256"],
        "download_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "format": fmt,
        "declared_export_options": opts,
        "option_values_complete": "unknown" not in opts.values(),
        "official_download_provenance_authenticated": False,
        "independent_scholarly_review": "PENDING",
        "reader_activation": False, "public_release": False,
        "license_attribution": "Tanzil Project / https://tanzil.net / CC BY 3.0",
        "diagnostics": differences,
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--official", required=True, type=Path)
    parser.add_argument("--out", type=Path,
                        default=Path(".staging/official_unicode_diagnostics.json"))
    parser.add_argument("--samples", type=int, default=12)
    for name in OPTION_NAMES:
        parser.add_argument("--"+name, required=True,
                            choices=sorted(ALLOWED_OPTIONS))
    args = parser.parse_args()
    try:
        official = require_downloaded_file(args.official)
        output = args.out.resolve()
        staging = (ROOT / ".staging").resolve()
        if not output.is_relative_to(staging):
            raise IntegrityError("Diagnostic report must stay in private .staging/")
        opts = {name: getattr(args, name) for name in OPTION_NAMES}
        report = make_report(official, opts, args.samples)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",
                          encoding="utf-8")
        d = report["diagnostics"]
        print(json.dumps({
            "status": report["status"],
            "download_sha256": report["download_sha256"],
            "exact": d["exact"],
            "tatweel_only_diagnostic": d["tatweel_only_diagnostic"],
            "optional_small_meem_insertions_diagnostic": d["optional_small_meem_insertions_diagnostic"],
            "marks_or_tatweel_diagnostic": d["marks_or_tatweel_diagnostic"],
            "other_string_differences": d["other_string_differences"],
            "top_removed_codepoints": d["most_removed_codepoints"][:10],
            "top_added_codepoints": d["most_added_codepoints"][:10],
            "report": str(output), "approval": "PENDING", "release": "BLOCKED",
        }, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, UnicodeError, TypeError, KeyError) as error:
        print("FAIL: "+str(error), file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
