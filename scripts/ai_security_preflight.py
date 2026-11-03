#!/usr/bin/env python3
"""Source-only Safwa AI safety checks. No file contents or secrets are printed.

Complements, but does not replace, Gitleaks, Semgrep, OS sandboxing and
independent review. Checks tracked files, not ignored local files.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SENSITIVE_FILE = re.compile(
    r"(?:^|/)(?:\.env(?:\.[^/]*)?|google-services\.json|"
    r"GoogleService-Info\.plist|service-account[^/]*\.json|"
    r"firebase-adminsdk[^/]*\.json|"
    r"[^/]+\.(?:pem|p12|pfx|key|jks|keystore|sqlite|sqlite3|db|"
    r"tfstate|tfvars|mobileprovision|har|pcap|pcapng))$",
    re.IGNORECASE,
)
SENSITIVE_DIRS = {"private", "client_data", "secrets", "credentials", ".local"}
ASSIGNMENT = re.compile(
    rb"(?i)(?:api[_-]?key|secret|private[_-]?key|access[_-]?token|"
    rb"password|client[_-]?secret)\s*[:=]\s*[\x22\x27]"
    rb"([^\x22\x27\r\n]{12,})[\x22\x27]"
)
# Only scan executable/config sources to avoid false alarms in safety docs.
CODE_SUFFIXES = {".py", ".dart", ".sh", ".yml", ".yaml", ".json", ".toml"}
ALLOWED_TEST_SAMPLES = (b"example", b"synthetic", b"placeholder", b"dummy", b"replace_me")


def protected_path(path: str) -> bool:
    if path in {".env.example", ".env.sample"}:
        return False
    segments = path.split("/")
    return (
        any(part.lower() in SENSITIVE_DIRS for part in segments)
        or bool(SENSITIVE_FILE.search(path))
        or path in {".claude/settings.local.json"}
    )


def suspicious_assignment(blob: bytes) -> bool:
    for item in ASSIGNMENT.finditer(blob):
        value = item.group(1).strip().lower()
        if not any(sample in value for sample in ALLOWED_TEST_SAMPLES):
            return True
    return False


def tracked_paths(root: Path) -> list[str]:
    cp = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        capture_output=True, check=True,
    )
    return [item.decode("utf-8", "surrogateescape")
            for item in cp.stdout.split(b"\0") if item]


def check(root: Path = ROOT) -> list[str]:
    issues: list[str] = []
    names = tracked_paths(root)
    if len(names) != len(set(names)):
        issues.append("Git index lists duplicate file names")
    for name in names:
        if protected_path(name):
            issues.append(f"Protected file tracked in Git: {name}")
            continue
        path = root / name
        if not path.is_file() or path.is_symlink():
            continue
        if path.suffix not in CODE_SUFFIXES:
            continue
        # Do not print an actual secret or its matching line to stdout.
        if path.stat().st_size > 1_000_000:
            continue  # Dedicated CI Gitleaks scans large content.
        if suspicious_assignment(path.read_bytes()):
            issues.append(f"Possible credential literal (content redacted): {name}")
    policy = root / "config/release_policy.json"
    status = root / "config/feature_status.json"
    if policy.is_file() and status.is_file():
        p = json.loads(policy.read_text())
        s = json.loads(status.read_text())
        if p.get("public_release_enabled") is not False:
            issues.append("Public release unexpectedly enabled")
        if s.get("release_authorized") is not False or s.get("public_release") != "BLOCKED":
            issues.append("Safwa release status no longer blocked")
        if s.get("quran_reader_activation") != "BLOCKED":
            issues.append("Quran reader unexpectedly enabled")
        if s.get("scholarly_approvals_authenticated") != 0:
            issues.append("Scholarly approvals changed; require authenticated review")
    return issues


def main() -> int:
    try:
        problems = check()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"FAIL: Safwa AI security inspection cannot complete: {type(exc).__name__}", file=sys.stderr)
        return 1
    if problems:
        for problem in problems:
            print("FAIL: " + problem, file=sys.stderr)
        return 1
    print("PASS: Safwa tracked-file confidentiality and release-source policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
