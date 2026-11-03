#!/usr/bin/env python3
"""SAFWA-017 zero-dependency safety policy for tracked/staged paths and release.

This is a complement to Gitleaks, not a content-based secret scanner.
It must never print file contents or scan private directories.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
PRIVATE_NAMES = frozenset({
    "google-services.json", "googleservice-info.plist",
    "key.properties", "id_rsa", "id_ed25519",
})
PRIVATE_DIRS = frozenset({
    "secrets", "credentials", "private", "customer-data",
    "customer_data", "client-data", "client_data",
})
PRIVATE_SUFFIXES = (
    ".pem", ".p8", ".p12", ".pfx", ".jks", ".keystore",
    ".mobileprovision", ".provisionprofile", ".secret",
    ".secrets", ".token", ".sqlite", ".sqlite3", ".db",
    ".db-wal", ".db-shm", ".sqlite-wal", ".sqlite-shm",
)
NONRELEASABLE = (
    "public_release_enabled", "content_lock_approved",
    "independent_religious_review_approved",
    "brand_rights_confirmed", "privacy_security_review_approved",
    "store_metadata_review_approved",
)


def sensitive_path(path):
    normalized = path.replace("\\", "/").lstrip("./")
    name = PurePosixPath(normalized).name.lower()
    dirs = {part.lower() for part in PurePosixPath(normalized).parts[:-1]}
    if dirs & PRIVATE_DIRS or name in PRIVATE_NAMES:
        return True
    if name == ".env" or (name.startswith(".env.")
                          and not name.endswith(".example")):
        return True
    if "service-account" in name or "service_account" in name:
        return True
    if name.endswith(PRIVATE_SUFFIXES) or name.startswith("firebase-adminsdk"):
        return True
    if name.endswith((".log", ".har", ".dump", ".backup")):
        return True
    return False


def list_git_paths(*, staged=False, repo=ROOT):
    args = (
        ["git", "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"]
        if staged else ["git", "ls-files", "-z"]
    )
    output = subprocess.run(args, cwd=repo, check=True,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return [name.decode("utf-8", errors="strict") for name
            in output.stdout.split(b"\0") if name]


def ensure_release_locked(policy, status):
    if not isinstance(policy, dict) or not isinstance(status, dict):
        raise ValueError("Malformed Safwa release policy")
    if any(policy.get(name) is not False for name in NONRELEASABLE):
        raise ValueError("Safwa release/brand gate is not locked")
    if status.get("release_authorized") is not False or (
        status.get("public_release") != "BLOCKED"
        or status.get("quran_reader_activation") != "BLOCKED"
        or status.get("scholarly_approvals_authenticated") != 0
    ):
        raise ValueError("Safwa public/Quran approval gate is not locked")


def check(*, repo=ROOT, staged=False):
    paths = list_git_paths(staged=staged, repo=repo)
    offending = [p for p in paths if sensitive_path(p)]
    if offending:
        # Never read or echo contents, credentials, or internal file paths.
        raise ValueError(
            "Sensitive file path in git " +
            ("staging area" if staged else "tracked index") +
            "; inspect with git status, unstage securely, rotate leaks")
    policy = json.loads(
        (repo / "config/release_policy.json").read_text(encoding="utf-8")
    )
    status = json.loads(
        (repo / "config/feature_status.json").read_text(encoding="utf-8")
    )
    ensure_release_locked(policy, status)
    return len(paths)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--staged", action="store_true",
                        help="Inspect added/modified staged file paths only")
    args = parser.parse_args()
    try:
        count = check(staged=args.staged)
        print("PASS: Safwa secret-path and fail-closed release policy; "
              + str(count) + " git paths checked")
        return 0
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError,
            json.JSONDecodeError) as exc:
        print("FAIL: Safwa repository security policy: "
              + type(exc).__name__ + " (details withheld to prevent leaks)",
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
