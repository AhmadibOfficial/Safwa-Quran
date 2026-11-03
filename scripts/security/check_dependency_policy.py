#!/usr/bin/env python3
"""Fail closed when direct Dart packages change without a baseline review.

This inventories direct declarations; it does NOT check transitive
vulnerabilities, authorship, publisher authenticity, or license safety.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY = re.compile(r"^  ([a-zA-Z_][a-zA-Z_0-9]*):(?:\s*(.*))?$")


def declared_dependencies(pubspec):
    groups = {"dependencies": {}, "dev_dependencies": {}}
    lines = pubspec.splitlines()
    section = None
    for index, line in enumerate(lines):
        if line.startswith("dependencies:"):
            section = "dependencies"
            continue
        if line.startswith("dev_dependencies:"):
            section = "dev_dependencies"
            continue
        if line and not line.startswith((" ", "#")):
            section = None
        if section is None or not line.startswith("  ") or line.startswith("    "):
            continue
        match = KEY.fullmatch(line.strip("\r"))
        if not match:
            continue
        name, raw = match.groups()
        if name in groups[section]:
            raise ValueError("Duplicate direct dependency declaration")
        value = (raw or "").strip().strip("'\"")
        if not value:
            if index + 1 >= len(lines) or lines[index + 1].strip() != "sdk: flutter":
                raise ValueError("Unsupported or dynamic direct dependency source")
            value = "sdk:flutter"
        groups[section][name] = value
    return groups


def validate(pubspec, baseline):
    expected = {section: baseline[section] for section in (
        "dependencies", "dev_dependencies")}
    if baseline.get("status") != "BASELINE_PENDING_INDEPENDENT_DEPENDENCY_REVIEW":
        raise ValueError("Unexpected dependency review evidence")
    actual = declared_dependencies(pubspec)
    if actual != expected:
        raise ValueError(
            "Flutter package declarations changed: require human publisher, "
            "license, advisory and version review, then update baseline"
        )
    return True


def main():
    try:
        baseline = json.loads((ROOT / "config/dependency_review_baseline.json")
                              .read_text(encoding="utf-8"))
        pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        validate(pubspec, baseline)
        print("PASS: Direct Flutter dependencies match recorded review baseline")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print("FAIL: Direct dependency review gate: " + type(exc).__name__,
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
