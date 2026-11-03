"""Direct dependency changes require independent review."""
import json
import unittest
from pathlib import Path

from scripts.security.check_dependency_policy import (
    ROOT, declared_dependencies, validate,
)


class DependencyReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        cls.baseline = json.loads(
            (ROOT / "config/dependency_review_baseline.json")
            .read_text(encoding="utf-8")
        )

    def test_current_declared_dependencies_match_baseline(self):
        self.assertTrue(validate(self.pubspec, self.baseline))

    def test_new_package_requires_review(self):
        altered = self.pubspec.replace(
            "dependencies:\n", "dependencies:\n  unreviewed_package: ^1.0.0\n", 1
        )
        with self.assertRaises(ValueError):
            validate(altered, self.baseline)

    def test_version_change_requires_review(self):
        altered = self.pubspec.replace(
            "shared_preferences: ^2.5.3", "shared_preferences: ^9.9.9"
        )
        with self.assertRaises(ValueError):
            validate(altered, self.baseline)

    def test_duplicate_package_rejected(self):
        with self.assertRaises(ValueError):
            declared_dependencies(
                "dependencies:\n  example: ^1.0.0\n  example: ^1.1.0\n"
            )

    def test_baseline_is_not_claimed_security_approval(self):
        self.assertEqual(
            self.baseline["status"],
            "BASELINE_PENDING_INDEPENDENT_DEPENDENCY_REVIEW",
        )


if __name__ == "__main__":
    unittest.main()
