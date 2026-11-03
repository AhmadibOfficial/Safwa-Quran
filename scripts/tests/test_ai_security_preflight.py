import unittest

from scripts.ai_security_preflight import protected_path, suspicious_assignment


class SafwaAIPolicyTests(unittest.TestCase):
    def test_sensitive_paths_blocked(self):
        for p in [
            ".env", ".env.production", "apps/api/.env.test",
            "private/export.txt", "secrets/admin.json", "ios/signing.p12",
            "android/app/google-services.json", "safwa.db", "logs/debug.har",
            "client_data/data.tsv",
        ]:
            with self.subTest(path=p):
                self.assertTrue(protected_path(p))

    def test_synthetic_env_template_allowed(self):
        self.assertFalse(protected_path(".env.example"))
        self.assertFalse(protected_path(".env.sample"))

    def test_literal_credentials_blocked_without_disclosure(self):
        self.assertTrue(suspicious_assignment(b'api_' + b'key = "test_real_credential_not_for_use"'))
        self.assertTrue(suspicious_assignment(b'pass' + b'word: "a_long_secret_for_testing"'))

    def test_real_looking_value_with_embedded_fixture_marker_is_rejected(self):
        self.assertTrue(suspicious_assignment(
            b'api_' + b'key = "privatelookingvaluesynthetic_suffix_123"'
        ))

    def test_explicitly_synthetic_backup_password_is_allowed(self):
        self.assertFalse(suspicious_assignment(
            b'const testPassword = "synthetic_backup_fixture_not_a_real_password_2026"'
        ))

    def test_redacted_synthetic_values_are_allowed(self):
        self.assertFalse(suspicious_assignment(b'api_key = "synthetic_api_key"'))
        self.assertFalse(suspicious_assignment(b'password: "replace_me_only"'))


if __name__ == "__main__":
    unittest.main()
