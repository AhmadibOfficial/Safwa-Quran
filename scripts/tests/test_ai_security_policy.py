"""SAFWA-017 confidentiality and release-policy checks, synthetic only."""
import unittest

from scripts.security.check_repo_security import (
    NONRELEASABLE, check, ensure_release_locked, sensitive_path,
)


class AISecurityPolicyTests(unittest.TestCase):
    def test_repository_release_remains_locked(self):
        self.assertGreater(check(), 0)

    def test_sensitive_paths_are_blocked(self):
        for path in (".env", "app/.env.local", "secrets/synthetic.txt",
                     "signing/test.pem", "app/data.sqlite3",
                     "android/app/google-services.json"):
            with self.subTest(path=path):
                self.assertTrue(sensitive_path(path))

    def test_safe_source_paths_are_allowed(self):
        for path in (".env.example", "pubspec.yaml",
                     "assets/data/chapters.tsv", "AGENTS.md"):
            with self.subTest(path=path):
                self.assertFalse(sensitive_path(path))

    def test_brand_approval_must_remain_pending(self):
        policy = {name: False for name in NONRELEASABLE}
        status = {"release_authorized": False,
                  "public_release": "BLOCKED",
                  "quran_reader_activation": "BLOCKED",
                  "scholarly_approvals_authenticated": 0}
        ensure_release_locked(policy, status)
        policy["brand_rights_confirmed"] = True
        with self.assertRaises(ValueError):
            ensure_release_locked(policy, status)

    def test_unknown_approval_state_is_not_accepted(self):
        with self.assertRaises(ValueError):
            ensure_release_locked({}, {})

    def test_quran_reader_unlock_does_not_pass(self):
        policy = {name: False for name in NONRELEASABLE}
        status = {"release_authorized": False,
                  "public_release": "BLOCKED",
                  "quran_reader_activation": "ENABLED",
                  "scholarly_approvals_authenticated": 0}
        with self.assertRaises(ValueError):
            ensure_release_locked(policy, status)


if __name__ == "__main__":
    unittest.main()
