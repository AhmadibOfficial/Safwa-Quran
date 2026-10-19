#!/usr/bin/env python3
"""Proof for Safwa's ONE selected tanween-ON Quran content candidate.

Read-only comparison, strictly pending official provenance, qualified review,
authorized font rendering, and separate app activation. No normalization.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from compare_uthmani_editions import IntegrityError, parse_primary
from build_review_pack import SOURCE_A
from prove_quran_content import content_digest
from verify_official_tanzil import analyze, read_official_export, require_downloaded_file
from official_unicode_diagnostics import only_added_small_meems

ROOT = Path(__file__).resolve().parents[1]
SELECTION = ROOT / "config/quran_text_selection.json"
SMALL_MEEMS = ("\u06ed", "\u06e2")
REQUIRED_OPTIONS = ("marks", "sajdah", "rub", "tatweel", "stanween")


def count_exact_and_insertions(pinned, selected):
    """Strict comparison of unchanged text; never returns an approved status."""
    if not pinned or list(pinned) != list(selected):
        raise IntegrityError("Selected Quran has missing or reordered references")
    exact = 0
    marker_only = 0
    added = Counter()
    for reference, original in pinned.items():
        proposed = selected[reference]
        if original == proposed:
            exact += 1
            continue
        if not only_added_small_meems(original, proposed):
            raise IntegrityError(
                "Selected Quran differs by more than small-meem insertions at %d:%d" % reference
            )
        marker_only += 1
        for marker in SMALL_MEEMS:
            count = proposed.count(marker) - original.count(marker)
            if count < 0:
                raise IntegrityError("A Quranic marker was removed")
            added["U+%04X" % ord(marker)] += count
    return {
        "exact_verses": exact,
        "small_meem_insertions_only_verses": marker_only,
        "added_small_meem_codepoints": dict(sorted(added.items())),
        "total_verses": len(pinned),
    }


def verify_selected(path, config=SELECTION):
    settings = json.loads(config.read_text(encoding="utf-8"))
    if (settings.get("status") != "INTENDED_NOT_APPROVED"
        or settings.get("sequential_tanween") != "on"
        or settings.get("reader_activation_enabled") is not False
        or settings.get("public_release_allowed") is not False
        or settings.get("scholarly_review") != "PENDING"):
        raise IntegrityError("Selection is not locked to the unapproved ON edition")
    expected_file_hash = settings["selected_original_file_sha256"]
    if not isinstance(expected_file_hash, str) or len(expected_file_hash) != 64:
        raise IntegrityError("Selected download SHA-256 must be pinned")
    options = settings.get("declared_export_options", {})
    if set(options) != set(REQUIRED_OPTIONS) or options.get("stanween") != "on":
        raise IntegrityError("Selected Quran export must explicitly require tanween ON")
    if not all(v in {"on", "off", "unknown"} for v in options.values()):
        raise IntegrityError("Unrecognized source export setting")

    path = require_downloaded_file(path)
    raw = path.read_bytes()
    got = hashlib.sha256(raw).hexdigest()
    if got != expected_file_hash:
        raise IntegrityError("Selected tanween Quran source SHA-256 changed")

    base = analyze(path, options)
    primary = parse_primary(SOURCE_A.read_bytes())
    selected, fmt = read_official_export(raw, list(primary))
    if fmt != "txt-2" or len(selected) != 6236:
        raise IntegrityError("Selected Quran must contain 6236 numbered verses")
    comparison = count_exact_and_insertions(primary, selected)
    if (comparison["exact_verses"] != base["exact_verse_matches"]
        or comparison["small_meem_insertions_only_verses"] != base["other_differences_count"]
        or comparison["exact_verses"] +
            comparison["small_meem_insertions_only_verses"] != 6236):
        raise IntegrityError("Content-proof counters disagree")
    expected_counts = settings["previously_observed_diagnostics"]
    if any(comparison.get(field) != expected_counts.get(field)
           for field in ("exact_verses", "small_meem_insertions_only_verses",
                         "added_small_meem_codepoints")):
        raise IntegrityError("Candidate relation differs from pinned earlier evidence")

    return {
        "status": "SELECTED_TANWEEN_ON_TECHNICAL_PROOF_ONLY",
        "one_intended_reading_edition": "Tanzil Uthmani v1.1 sequential tanween ON",
        "selected_source_original_sha256": got,
        "selected_ordered_verse_content_sha256": content_digest(selected),
        "pinned_comparison_content_sha256": content_digest(primary),
        "comparison_diagnostics": comparison,
        "selected_file_format": fmt,
        "declared_export_options": options,
        "all_export_option_states_known": "unknown" not in options.values(),
        "independent_download_provenance_authenticated": False,
        "font_rendering_and_distribution_rights_verified": False,
        "qualified_reviewer_one": "PENDING",
        "qualified_reviewer_two": "PENDING",
        "public_release_allowed": False,
        "reader_activation_allowed": False,
        "warning": "Text correspondence is not religious approval; ON text must render correctly with a licensed compatible Quran font.",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path,
                        help="Existing original sequential-tanween ON downloaded text")
    parser.add_argument("--out", type=Path,
                        default=Path(".staging/selected_tanween_content_proof.json"))
    args = parser.parse_args()
    try:
        out = args.out.resolve()
        quarantine = (ROOT / ".staging").resolve()
        if not out.is_relative_to(quarantine):
            raise IntegrityError("Proof evidence must remain within private .staging/")
        proof = verify_selected(args.source)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
        print(json.dumps(proof, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, KeyError, TypeError, OSError, UnicodeError) as err:
        print("FAIL: " + str(err), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
