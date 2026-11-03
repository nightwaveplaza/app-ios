"""Exercise real OpenSSL containers without production signing credentials."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("prepare_signing_p12.sh").resolve()


class SigningContainerTests(unittest.TestCase):
    def test_modern_legacy_and_invalid_password(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = dict(os.environ, RUNNER_TEMP=directory,
                       DISTRIBUTION_P12_PASSWORD="test '$ & password",
                       P12_IMPORT_PASSWORD="temporary-test-password")

            def openssl(*args):
                return subprocess.run(["openssl", *args], cwd=root, env=env,
                                      check=True, capture_output=True)

            openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes",
                    "-keyout", "key.pem", "-out", "cert.pem", "-days", "1",
                    "-subj", "/CN=CI fixture")
            for legacy in (False, True):
                with self.subTest(legacy=legacy):
                    openssl("pkcs12", "-export", *(["-legacy"] if legacy else []),
                            "-inkey", "key.pem", "-in", "cert.pem", "-out", "source.p12",
                            "-passout", "env:DISTRIBUTION_P12_PASSWORD")
                    result = subprocess.run(
                        ["bash", str(SCRIPT), str(root / "source.p12"), str(root / "output.p12")],
                        env=env, capture_output=True, text=True, check=True)
                    self.assertIn("Source PKCS12 verified", result.stdout)
                    info = openssl("pkcs12", "-in", "output.p12", "-passin",
                                   "env:P12_IMPORT_PASSWORD", "-info", "-noout").stderr.decode()
                    self.assertIn("MAC: sha1", info)
                    self.assertIn("pbeWithSHA1And3-KeyTripleDES-CBC", info)
                    openssl("pkcs12", "-in", "output.p12", "-passin",
                            "env:P12_IMPORT_PASSWORD", "-clcerts", "-nokeys", "-out", "actual.pem")
                    self.assertEqual(openssl("x509", "-in", "cert.pem", "-outform", "DER").stdout,
                                     openssl("x509", "-in", "actual.pem", "-outform", "DER").stdout)
                    # Verify the private key also survives conversion
                    openssl("pkcs12", "-in", "output.p12", "-passin",
                            "env:P12_IMPORT_PASSWORD", "-nocerts", "-nodes", "-out", "actual-key.pem")
                    self.assertEqual(openssl("pkey", "-in", "key.pem", "-pubout").stdout,
                                     openssl("pkey", "-in", "actual-key.pem", "-pubout").stdout)
                    self.assertFalse(list(root.glob("plaza-p12.*")))
                    for password in (env["DISTRIBUTION_P12_PASSWORD"], env["P12_IMPORT_PASSWORD"]):
                        self.assertNotIn(password, result.stdout + result.stderr)

            result = subprocess.run(
                ["bash", str(SCRIPT), str(root / "source.p12"), str(root / "invalid.p12")],
                env=dict(env, DISTRIBUTION_P12_PASSWORD="wrong"), capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("cannot verify the source", result.stderr)
            self.assertFalse((root / "invalid.p12").exists())
            self.assertFalse(list(root.glob("plaza-p12.*")))


if __name__ == "__main__":
    unittest.main()
