#!/usr/bin/env python3
"""Fail-closed SAFWA-016 offline recitation audio asset & policy audit.

Do not treat user-supplied manifest evidence as a legal license or religious
approval. Until independent review and release policy gates are implemented,
ALL public/app-packaged audio remains locked, with no recordings bundled.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/data/offline_recitation_manifest.json"
AUDIO_SUFFIXES = {".mp3", ".m4a", ".aac", ".ogg", ".wav", ".flac"}


def assert_locked_manifest(data):
    if not isinstance(data, dict):
        raise ValueError("Audio manifest must be an object")
    if data.get("format") != "safwa-offline-recitation" or data.get("schema") != 1:
        raise ValueError("Invalid audio manifest format or version")
    if data.get("status") != "LOCKED" or data.get("tracks") != []:
        raise ValueError("Unapproved Quran audio must not be enabled or bundled")


def check(root=ROOT):
    root = Path(root)
    manifest = root / "assets/data/offline_recitation_manifest.json"
    assert_locked_manifest(json.loads(manifest.read_text(encoding="utf-8")))

    for directory in (root / "assets", root / "sources"):
        if directory.exists():
            for candidate in directory.rglob("*"):
                if candidate.suffix.lower() in AUDIO_SUFFIXES:
                    raise ValueError(
                        "Unexpected audio file in protected content tree: "
                        + str(candidate.relative_to(root))
                    )
    main = (root / "lib/main.dart").read_text(encoding="utf-8")
    if "offline_recitation_player.dart" in main:
        raise ValueError("Unapproved player must not be imported by main")
    page = (root / "lib/offline_recitation_page.dart").read_text(
        encoding="utf-8"
    )
    if "offline_recitation_player.dart" in page:
        raise ValueError("Unapproved player must not be imported by public UI")
    status = json.loads((root / "config/feature_status.json").read_text(
        encoding="utf-8"
    ))
    if (status.get("public_release") != "BLOCKED"
            or status.get("quran_reader_activation") != "BLOCKED"
            or status.get("scholarly_approvals_authenticated") != 0):
        raise ValueError("Public Quran or audio release guard changed")
    return True


def main():
    try:
        check()
        print("PASS: SAFWA-016 offline recitation locked, no audio assets or release")
        return 0
    except (OSError, ValueError, TypeError, KeyError) as exc:
        print("FAIL: SAFWA-016 audio source gate: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
