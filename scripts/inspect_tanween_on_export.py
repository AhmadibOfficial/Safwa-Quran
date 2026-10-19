#!/usr/bin/env python3
"""Forensic comparison of two TANWEEN-ON exports, without editing Quran text.

The older copy is only private comparison evidence; never a second reader edition.
All outputs are diagnostic only, NOT religious approval or authenticated provenance.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import unicodedata

from compare_uthmani_editions import IntegrityError, parse_primary
from build_review_pack import SOURCE_A
from prove_quran_content import content_digest
from verify_official_tanzil import analyze, read_official_export, require_downloaded_file

ROOT = Path(__file__).resolve().parents[1]
# Deletions consistent with specifically disabled Tanzil export switches.
# Individual codepoints do not establish all resulting Mushaf signs are acceptable.
EXPECTED_REMOVABLE = frozenset(
    "\u0640\u06d6\u06d7\u06d8\u06d9\u06da\u06db\u06de\u06e9"
)
OLD_SHA = "aa0bf9278a177a12e6d9bef621ce37a1d24fa35168b5ae9c13ebcbe01e3686cf"
NEW_SHA = "f9a45b967b4b3407d0c7ca97ac122bbc8afb2d005b0af81e3a0a2c07d64fa94f"


def deletion_of_only_allowed(old, new, removable=EXPECTED_REMOVABLE):
    """Byte-exact codepoint subsequence test; allows deleting ONLY listed marks."""
    i = 0
    deleted = 0
    for char in old:
        if i < len(new) and char == new[i]:
            i += 1
        elif char in removable:
            deleted += 1
        else:
            return False
    return i == len(new) and deleted > 0


def letters(text):
    """Strict in-order Unicode-letter signature for diagnostic alarms only."""
    # U+0640 TATWEEL is Unicode category Lm (modifier letter), but it is
    # explicitly a removable elongation mark for this export comparison.
    # Do not misreport tatweel deletion as an Arabic base-letter change.
    return "".join(ch for ch in text if ch != "\u0640" and
                   unicodedata.category(ch).startswith("L"))


def examine_pair(reference, current, sample_limit=12):
    if not reference or list(reference) != list(current):
        raise IntegrityError("Export pair must have matching ordered verse references")
    if sample_limit < 0:
        raise IntegrityError("Sample limit must not be negative")
    counts = Counter()
    absent = Counter()
    added = Counter()
    examples = []
    unresolved = []
    spacing_cases = []
    for ref, original in reference.items():
        selected = current[ref]
        if original == selected:
            classification = "exact"
        elif deletion_of_only_allowed(original, selected):
            classification = "listed_annotation_deletions_only"
        elif deletion_of_only_allowed(
            original.replace(" ", ""), selected.replace(" ", "")
        ):
            classification = "spacing_changes_need_manual_review"
        elif letters(original) != letters(selected):
            classification = "unicode_letter_changes_unresolved"
        else:
            classification = "other_unicode_differences_unresolved"
        counts[classification] += 1
        if classification == "spacing_changes_need_manual_review":
            before, after = Counter(original), Counter(selected)
            spacing_cases.append({
                "reference": f"{ref[0]}:{ref[1]}",
                "classification": classification,
                "removed_space_count": max(before[" "] - after[" "], 0),
                "added_space_count": max(after[" "] - before[" "], 0),
                "older_original_verbatim": original,
                "new_original_verbatim": selected,
            })
        if classification in ("unicode_letter_changes_unresolved",
                              "other_unicode_differences_unresolved"):
            previous, proposed = Counter(original), Counter(selected)
            unresolved.append({
                "reference": f"{ref[0]}:{ref[1]}",
                "classification": classification,
                "removed_codepoints": [f"U+{ord(c):04X}"
                                       for c in sorted(previous - proposed)],
                "added_codepoints": [f"U+{ord(c):04X}"
                                     for c in sorted(proposed - previous)],
                "older_original_verbatim": original,
                "new_original_verbatim": selected,
            })
        if original != selected:
            # Character inventories are unambiguous; alignment opcodes aren't
            # necessarily unambiguous in repeated Arabic strings.
            before = Counter(original)
            after = Counter(selected)
            absent.update(before - after)
            added.update(after - before)
            if len(examples) < sample_limit:
                examples.append({
                    "reference": f"{ref[0]}:{ref[1]}",
                    "classification": classification,
                    "older_original_verbatim": original,
                    "new_original_verbatim": selected,
                })
    for field in (
        "exact", "listed_annotation_deletions_only",
        "spacing_changes_need_manual_review",
        "unicode_letter_changes_unresolved",
        "other_unicode_differences_unresolved"
    ):
        counts.setdefault(field, 0)
    def codepoints(counter):
        return [
            {"codepoint": f"U+{ord(ch):04X}",
             "name": unicodedata.name(ch, "UNASSIGNED"),
             "count": count,
             "listed_annotation": ch in EXPECTED_REMOVABLE}
            for ch, count in sorted(counter.items(), key=lambda p: (-p[1], ord(p[0])))
        ]
    return {
        "verse_count": len(reference),
        "categories": dict(counts),
        "missing_character_inventory": codepoints(absent),
        "new_character_inventory": codepoints(added),
        "example_verbatim_pairs": examples,
        # All unresolved verse strings go only into the ignored local report;
        # the terminal prints limited codepoints and references, not Arabic text.
        "unresolved_case_diagnostics": unresolved,
        # Kept privately for qualified review; stripping all spaces in a
        # comparison NEVER authorizes removing a word boundary.
        "spacing_case_diagnostics": spacing_cases,
        "warning": "Even 'listed annotation deletions only' is a technical relationship, not confirmation that the new Arabic rendition is religiously sufficient. All spacing changes are independently unresolved.",
    }


def inspect_files(old_path, new_path, sample_limit=12):
    old = require_downloaded_file(Path(old_path))
    new = require_downloaded_file(Path(new_path))
    if old == new:
        raise IntegrityError("Use two different preserved export paths")
    old_raw, new_raw = old.read_bytes(), new.read_bytes()
    if hashlib.sha256(old_raw).hexdigest() != OLD_SHA:
        raise IntegrityError("Older reference ON file does not match prior verified SHA-256")
    if hashlib.sha256(new_raw).hexdigest() != NEW_SHA:
        raise IntegrityError("New ON candidate does not match recorded SHA-256")
    original = parse_primary(SOURCE_A.read_bytes())
    old_map, old_fmt = read_official_export(old_raw, list(original))
    new_map, new_fmt = read_official_export(new_raw, list(original))
    if old_fmt != "txt-2" or new_fmt != "txt-2" or len(old_map) != 6236:
        raise IntegrityError("Require both complete numbered Uthmani exports")
    # analyze rechecks source blob SHA-1, copyright text, catalog and verse order.
    old_audit = analyze(old, dict(marks="unknown", sajdah="unknown",
                                  rub="unknown", tatweel="unknown", stanween="on"))
    new_audit = analyze(new, dict(marks="off", sajdah="off",
                                  rub="off", tatweel="off", stanween="on"))
    d = examine_pair(old_map, new_map, sample_limit)
    return {
        "status": "PRIVATE_NEW_EXPORT_FORENSIC_ONLY",
        "older_on_source_original_sha256": OLD_SHA,
        "new_on_candidate_original_sha256": NEW_SHA,
        "new_on_ordered_verse_content_sha256": content_digest(new_map),
        "older_on_ordered_verse_content_sha256": content_digest(old_map),
        "old_exact_verses_against_pinned": old_audit["exact_verse_matches"],
        "new_exact_verses_against_pinned": new_audit["exact_verse_matches"],
        "new_user_declared_options": dict(marks="off", sajdah="off",
                                          rub="off", tatweel="off", stanween="on"),
        "provenance_independently_authenticated": False,
        "scholarly_review": "PENDING",
        "reading_edition_selection_unchanged": True,
        "reader_activation_allowed": False,
        "public_release_allowed": False,
        "analysis": d,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--old-on", type=Path, required=True)
    parser.add_argument("--new-on", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--out", type=Path,
                        default=Path(".staging/2026-10-19-on-export-forensic.json"))
    args = parser.parse_args()
    try:
        target = args.out.resolve()
        if not target.is_relative_to((ROOT / ".staging").resolve()):
            raise IntegrityError("Comparison report must remain in private .staging/")
        report = inspect_files(args.old_on, args.new_on, args.samples)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                          encoding="utf-8")
        a = report["analysis"]
        print(json.dumps({
            "status": report["status"],
            "new_candidate_sha256": report["new_on_candidate_original_sha256"],
            "new_content_sha256": report["new_on_ordered_verse_content_sha256"],
            "verse_count": a["verse_count"],
            "categories": a["categories"],
            "missing_character_inventory": a["missing_character_inventory"][:30],
            "new_character_inventory": a["new_character_inventory"][:30],
            "unresolved_case_count": len(a["unresolved_case_diagnostics"]),
            "unresolved_case_summaries": [
                {k: v for k, v in item.items()
                 if k not in ("older_original_verbatim", "new_original_verbatim")}
                for item in a["unresolved_case_diagnostics"][:50]
            ],
            "private_report": str(target),
            "approval": "PENDING", "release": "BLOCKED"
        }, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, KeyError, OSError, UnicodeError, TypeError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
