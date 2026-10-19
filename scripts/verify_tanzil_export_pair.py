#!/usr/bin/env python3
"""Compare TWO Tanzil download candidates without modifying Quran text.

Both files are supplied by the operator; hashes, user-stated export options,
and byte-exact Unicode comparisons are evidence only, NOT provenance,
scriptural verification, or release authorization.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from compare_uthmani_editions import IntegrityError, parse_primary
from build_review_pack import SOURCE_A, CATALOG
from official_unicode_diagnostics import only_added_small_meems
from verify_official_tanzil import (
    ALLOWED_OPTIONS, analyze, read_official_export, require_downloaded_file,
)

ROOT = Path(__file__).resolve().parents[1]
OTHER_OPTIONS = ("marks", "sajdah", "rub", "tatweel")
SMALL_MEEMS = ("\u06ed", "\u06e2")


def compare_pair_maps(off, on):
    """Compare already-aligned unchanged verse strings from two downloads."""
    if not off or list(off) != list(on):
        raise IntegrityError("Tanween export pair has missing or out-of-order verses")
    same = 0
    additions_only = 0
    other = []
    introduced = Counter()
    for reference, first in off.items():
        second = on[reference]
        if first == second:
            same += 1
        elif only_added_small_meems(first, second):
            additions_only += 1
            for char in SMALL_MEEMS:
                difference = second.count(char) - first.count(char)
                if difference < 0:
                    raise IntegrityError("Small-meem insertion accounting inconsistent")
                introduced[char] += difference
        else:
            other.append(f"{reference[0]}:{reference[1]}")
    if same + additions_only + len(other) != len(off):
        raise IntegrityError("Unaccounted references in pair")
    return {
        "verses": len(off),
        "exact_between_exports": same,
        "off_to_on_small_meem_insertions_only": additions_only,
        "other_export_pair_differences_count": len(other),
        "other_export_pair_references": other,
        "inserted_small_meem_counts": {
            f"U+{ord(char):04X}": introduced[char] for char in SMALL_MEEMS
        },
        "only_small_meem_insertions_observed": additions_only > 0 and not other,
    }


def validate_settings(options):
    if set(options) != set(OTHER_OPTIONS):
        raise IntegrityError("Supply the four shared options: marks, sajdah, rub, tatweel")
    if any(value not in ALLOWED_OPTIONS for value in options.values()):
        raise IntegrityError("All export options must be on, off, or unknown")
    return "unknown" not in options.values()


def compare_downloads(off_path, on_path, shared_options):
    known = validate_settings(shared_options)
    off_path = require_downloaded_file(Path(off_path))
    on_path = require_downloaded_file(Path(on_path))
    if off_path == on_path:
        raise IntegrityError("OFF and ON inputs must be two separate preserved files")

    off_bytes = off_path.read_bytes()
    on_bytes = on_path.read_bytes()
    if off_bytes == on_bytes:
        raise IntegrityError("Downloaded files are byte-identical; controlled pair unproven")
    off_hash = hashlib.sha256(off_bytes).hexdigest()
    on_hash = hashlib.sha256(on_bytes).hexdigest()

    # Existing verifier rechecks pinned SHA, 114-surah catalog, 6236 verse
    # references, original download attribution, and text alignment.
    off_settings = dict(shared_options, stanween="off")
    on_settings = dict(shared_options, stanween="on")
    off_audit = analyze(off_path, off_settings)
    on_audit = analyze(on_path, on_settings)
    original = parse_primary(SOURCE_A.read_bytes())
    off_map, off_format = read_official_export(off_bytes, list(original))
    on_map, on_format = read_official_export(on_bytes, list(original))
    if off_format != on_format:
        raise IntegrityError("Controlled pair must have identical numbered/text format")
    results = compare_pair_maps(off_map, on_map)
    return {
        "status": "TWO_OPERATOR_SUPPLIED_EXPORTS_NOT_AUTHENTICATED",
        "claimed_download_page": "https://tanzil.net/download/",
        "source_provenance_authenticated": False,
        "source_type_claim": "Uthmani v1.1 (operator selection must be documented)",
        "shared_option_states_declared": shared_options,
        "shared_options_all_known": known,
        "stanween_disabled_in_off_file_claim": True,
        "stanween_enabled_in_on_file_claim": True,
        "file_format": off_format,
        "pinned_primary_sha256": off_audit["pinned_sha256"],
        "off_export_sha256": off_hash,
        "on_export_sha256": on_hash,
        "off_exact_vs_pinned": off_audit["exact_verse_matches"],
        "on_exact_vs_pinned": on_audit["exact_verse_matches"],
        "off_other_differences_vs_pinned": off_audit["other_differences_count"],
        "on_other_differences_vs_pinned": on_audit["other_differences_count"],
        "export_pair_comparison": results,
        "independent_scholarly_review": "PENDING",
        "quran_text_approval": False,
        "reader_activation_permitted": False,
        "public_release_permitted": False,
        "note": "A matching export pair does NOT authenticate provenance, recitation, or scholarly approval.",
    }


def main():
    p = argparse.ArgumentParser(
        description="Offline tanween OFF/ON comparison; never approves sacred text"
    )
    p.add_argument("--off", required=True, type=Path,
                   help="Preserved Uthmani text downloaded with sequential tanween OFF")
    p.add_argument("--on", required=True, type=Path,
                   help="Preserved Uthmani text downloaded with sequential tanween ON")
    for option in OTHER_OPTIONS:
        p.add_argument("--"+option, required=True, choices=sorted(ALLOWED_OPTIONS))
    p.add_argument("--out", type=Path,
                   default=Path(".staging/tanzil_tanween_pair_report.json"))
    args = p.parse_args()
    try:
        output = args.out.resolve()
        quarantine = (ROOT / ".staging").resolve()
        if not output.is_relative_to(quarantine):
            raise IntegrityError("Evidence report must stay in private .staging/")
        result = compare_downloads(args.off, args.on,
                                   {x: getattr(args, x) for x in OTHER_OPTIONS})
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",
                          encoding="utf-8")
        summary = {
            "status": result["status"],
            "source_provenance_authenticated": False,
            "shared_options_all_known": result["shared_options_all_known"],
            "off_sha256": result["off_export_sha256"],
            "on_sha256": result["on_export_sha256"],
            "off_exact_vs_pinned": result["off_exact_vs_pinned"],
            "on_exact_vs_pinned": result["on_exact_vs_pinned"],
            "pair_comparison": {
                k: v for k, v in result["export_pair_comparison"].items()
                if k != "other_export_pair_references"
            },
            "private_report": str(output),
            "scholarly_approval": "PENDING",
            "release": "BLOCKED",
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0 if result["export_pair_comparison"]["only_small_meem_insertions_observed"] else 2
    except (OSError, ValueError, TypeError, KeyError, UnicodeError) as error:
        print("FAIL: "+str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
