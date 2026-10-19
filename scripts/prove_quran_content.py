#!/usr/bin/env python3
"""Generate an immutable-text correspondence report for qualified Quran review.

This is NOT theological certification, independent download authentication,
or an application activation mechanism. Never modify Quran source strings.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from compare_uthmani_editions import IntegrityError, PRIMARY_SHA, git_sha, parse_primary
from build_review_pack import SOURCE_A, CATALOG
from verify_official_tanzil import (
    analyze, read_official_export, require_downloaded_file, ALLOWED_OPTIONS
)

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = ("marks", "sajdah", "rub", "tatweel", "stanween")

def content_digest(verses):
    """Digest ordered indexed UTF-8 verse strings without Arabic normalization.

    Serialization: one surah|ayah|verbatim_verse + LF per verse.
    Original text files are neither overwritten nor re-exported.
    """
    if len(verses) != 6236 and not verses:
        raise IntegrityError("Empty verse mapping")
    digest = hashlib.sha256()
    for key, verse in verses.items():
        if (not isinstance(key, tuple) or len(key) != 2 or
            not all(isinstance(v, int) and v > 0 for v in key) or
            not isinstance(verse, str) or not verse or
            any(char in verse for char in "\r\n|")):
            raise IntegrityError("Invalid indexed Quran text for digest")
        digest.update(f"{key[0]}|{key[1]}|{verse}\n".encode("utf-8"))
    return digest.hexdigest()

def compare_off(download_path, options, expected_download_sha256=None):
    if set(options) != set(OPTIONS):
        raise IntegrityError("Every Tanzil download option must be recorded")
    if any(value not in ALLOWED_OPTIONS for value in options.values()):
        raise IntegrityError("Unrecognized export option")
    if options["stanween"] != "off":
        raise IntegrityError("The exact-copy audit requires sequential tanween OFF")
    download = require_downloaded_file(Path(download_path))
    source_raw = SOURCE_A.read_bytes()
    if git_sha(source_raw) != PRIMARY_SHA:
        raise IntegrityError("Pinned source object SHA-1 changed")
    candidate_raw = download.read_bytes()
    download_sha = hashlib.sha256(candidate_raw).hexdigest()
    if expected_download_sha256 is not None and download_sha != expected_download_sha256:
        raise IntegrityError("Downloaded Quran file SHA-256 does not match pinned audit evidence")
    baseline = analyze(download, options)
    primary = parse_primary(source_raw)
    candidate, fmt = read_official_export(candidate_raw, list(primary))
    if fmt != "txt-2":
        raise IntegrityError("Require surah|ayah|text export for reproducible reviewer audit")
    if len(primary) != 6236 or list(primary) != list(candidate):
        raise IntegrityError("Incomplete or reordered Arabic source")
    different = [f"{s}:{v}" for (s,v) in primary
                 if primary[(s,v)] != candidate[(s,v)]]
    base_digest = content_digest(primary)
    candidate_digest = content_digest(candidate)
    if different or base_digest != candidate_digest:
        raise IntegrityError(f"Exact Quran string mismatch, first refs: {different[:5]}")
    if baseline["exact_verse_matches"] != 6236:
        raise IntegrityError("Official export comparison disagrees with exact-copy audit")
    return {
        "status": "TECHNICAL_CORRESPONDENCE_ONLY",
        "source_claim": "Tanzil Uthmani version 1.1, Hafs/Madina Mushaf basis",
        "source_reference_url": "https://tanzil.net/download/",
        "pinned_file_git_sha1": PRIMARY_SHA,
        "pinned_file_sha256": hashlib.sha256(source_raw).hexdigest(),
        "downloaded_file_sha256": download_sha,
        "content_digest_scheme": "UTF-8 of ordered surah|ayah|verbatim_verse\\n records; no Quran normalization",
        "pinned_verse_content_sha256": base_digest,
        "downloaded_verse_content_sha256": candidate_digest,
        "matched_verbatim_verses": 6236,
        "all_verses_byte_exact_after_parsing": True,
        "source_provenance_independently_authenticated": False,
        "declared_export_options": options,
        "all_option_values_known": "unknown" not in options.values(),
        "independent_qualified_reviewer_1": "PENDING",
        "independent_qualified_reviewer_2": "PENDING",
        "arabic_device_typography_review": "PENDING",
        "scholarly_content_approval": False,
        "reader_activation_allowed": False,
        "public_release_allowed": False,
        "warning": "Verse-string agreement is evidence of copying accuracy, not independent authentication or a religious ruling.",
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--off", type=Path, required=True)
    parser.add_argument("--expected-off-sha256",
                        help="Optionally require the same original download hash as the prior audit")
    parser.add_argument("--out", type=Path,
                        default=Path(".staging/quran_content_proof.json"))
    for name in OPTIONS:
        parser.add_argument("--"+name, choices=sorted(ALLOWED_OPTIONS), required=True)
    args = parser.parse_args()
    try:
        target = args.out.resolve()
        quarantine = (ROOT / ".staging").resolve()
        if not target.is_relative_to(quarantine):
            raise IntegrityError("Private Quran proof report must remain in .staging/")
        options = {name: getattr(args, name) for name in OPTIONS}
        result = compare_off(args.off, options, args.expected_off_sha256)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",
                          encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (OSError, UnicodeError, ValueError, TypeError, KeyError) as error:
        print("FAIL: "+str(error), file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
