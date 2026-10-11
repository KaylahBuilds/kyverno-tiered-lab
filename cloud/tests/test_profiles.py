"""Supplemental source checks; native Helm rendering and Terraform tests are separate."""
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]


class CloudProfiles(unittest.TestCase):
    def test_cloud_profiles_are_not_policies_or_secrets(self):
        for path in (ROOT / "cloud").rglob("*.yaml"):
            for document in yaml.safe_load_all(path.read_text(encoding="utf-8")):
                if isinstance(document, dict):
                    self.assertNotIn(document.get("kind"), {"Secret", "ClusterPolicy", "ValidatingPolicy"})

    def test_pins_and_explicit_auth_destination(self):
        main = (ROOT / "cloud/addons/main.tf").read_text()
        self.assertIn('version          = "3.9.1"', main)
        self.assertIn('config_context = var.kube_context', main)
        self.assertIn('config_path    = pathexpand(var.kubeconfig_path)', main)
        self.assertNotIn('token', main)
        self.assertNotIn('client_certificate', main)

    def test_shared_safety_values(self):
        data = yaml.safe_load((ROOT / "cloud/addons/values-common.yaml").read_text())
        self.assertEqual(data["global"]["nodeSelector"]["security-lab"], "enabled")
        self.assertTrue(data["config"]["excludeKyvernoNamespace"])
        self.assertFalse(data["features"]["generateValidatingAdmissionPolicy"]["enabled"])
        self.assertFalse(data["features"]["policyExceptions"]["enabled"])
        self.assertEqual(data["admissionController"]["podDisruptionBudget"]["minAvailable"], 2)

    def test_aks_annotation_is_string(self):
        data = yaml.safe_load((ROOT / "cloud/aks/values.yaml").read_text())
        self.assertEqual(data["config"]["webhookAnnotations"]["admissions.enforcer/disabled"], "true")


if __name__ == "__main__":
    unittest.main()
