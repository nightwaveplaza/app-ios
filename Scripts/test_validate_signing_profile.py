import datetime
import hashlib
import unittest

from validate_signing_profile import validate_profile


class SigningProfileTests(unittest.TestCase):
    def setUp(self):
        self.cert = b"fixture certificate DER"
        self.profile = {
            "UUID": "bcd53571-4344-4eca-be76-d03da6aa7be8",
            "Platform": ["iOS"],
            "TeamIdentifier": ["TEAM"],
            "ApplicationIdentifierPrefix": ["PREFIX"],
            "Entitlements": {"application-identifier": "PREFIX.com.example.app", "get-task-allow": False},
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) + datetime.timedelta(days=1),
            "DeveloperCertificates": [self.cert],
        }
        self.identities = f'  1) {hashlib.sha1(self.cert).hexdigest().upper()} "Apple Distribution: Fixture"\n     1 valid identities found\n'

    def validate(self):
        return validate_profile(self.profile, "TEAM", "com.example.app", self.identities)

    def test_valid_profile_preserves_uuid_and_allows_distinct_app_prefix(self):
        self.assertEqual(self.validate(), self.profile["UUID"])

    def test_unrelated_identity_is_rejected(self):
        self.identities = f'  1) {"A" * 40} "Apple Distribution: Other"\n'
        with self.assertRaisesRegex(ValueError, "No valid code-signing identity"):
            self.validate()

    def test_imported_certificate_without_usable_private_key_is_rejected(self):
        self.identities = "     0 valid identities found\n"
        with self.assertRaisesRegex(ValueError, "No valid code-signing identity"):
            self.validate()

    def test_profile_can_allow_multiple_certificates(self):
        self.profile["DeveloperCertificates"].insert(0, b"other certificate")
        self.validate()

    def test_wrong_platform_team_app_expiry_or_distribution_type_is_rejected(self):
        changes = (
            ("Platform", ["OSX"], "iOS provisioning"),
            ("TeamIdentifier", ["OTHER"], "different Apple team"),
            ("Entitlements", {"application-identifier": "PREFIX.com.other"}, "bundle identifier"),
            ("ExpirationDate", datetime.datetime(2000, 1, 1), "expired"),
            ("ProvisionedDevices", ["device"], "App Store Connect"),
            ("ProvisionsAllDevices", True, "App Store Connect"),
            ("UUID", "../../bad", "Invalid provisioning profile UUID"),
        )
        for key, value, error in changes:
            with self.subTest(key=key):
                self.setUp()
                self.profile[key] = value
                with self.assertRaisesRegex(ValueError, error):
                    self.validate()


if __name__ == "__main__":
    unittest.main()
