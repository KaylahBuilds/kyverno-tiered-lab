"""Repository guardrails only. This does NOT evaluate CEL or replace kyverno test."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
TIERS = {
    "tier-1-audit": ("kyverno-lab-tier1", "Audit", "Ignore", 4),
    "tier-2-enforce": ("kyverno-lab-tier2", "Deny", "Fail", 12),
    "tier-3-governance": ("kyverno-lab-tier3", "Deny", "Fail", 10),
}


def read_yaml(path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


class RepositoryBoundaries(unittest.TestCase):
    def test_policy_scope_and_failure_actions(self):
        for tier, (namespace, action, failure, _) in TIERS.items():
            with self.subTest(tier=tier):
                policy = read_yaml(ROOT / tier / "policy.yaml")
                self.assertEqual(policy["apiVersion"], "policies.kyverno.io/v1")
                self.assertEqual(policy["kind"], "ValidatingPolicy")
                spec = policy["spec"]
                self.assertEqual(spec["validationActions"], [action])
                self.assertEqual(spec["failurePolicy"], failure)
                self.assertEqual(spec["matchConditions"], [{
                    "name": "lab-namespace-only",
                    "expression": f"object.metadata.namespace == '{namespace}'",
                }])
                self.assertEqual(spec["autogen"]["podControllers"]["controllers"], [])
                for resource_rule in spec["matchConstraints"]["resourceRules"]:
                    self.assertEqual(resource_rule["apiGroups"], [""])
                    self.assertEqual(resource_rule["operations"], ["CREATE", "UPDATE"])
                    self.assertEqual(resource_rule["resources"], ["pods", "pods/ephemeralcontainers"])

    def test_native_test_manifests_cover_every_fixture_exactly_once(self):
        for tier, (_, _, _, count) in TIERS.items():
            with self.subTest(tier=tier):
                folder = ROOT / tier
                test = read_yaml(folder / "kyverno-test.yaml")
                policy = read_yaml(folder / "policy.yaml")
                self.assertEqual(test["apiVersion"], "cli.kyverno.io/v1alpha1")
                self.assertEqual(test["kind"], "Test")
                self.assertEqual(test["policies"], ["policy.yaml"])
                resources = [read_yaml(folder / file) for file in test["resources"]]
                fixture_names = [r["metadata"]["name"] for r in resources]
                self.assertEqual(len(fixture_names), count)
                self.assertEqual(len(set(fixture_names)), count)
                expected_names = []
                expected_results = []
                for result in test["results"]:
                    self.assertTrue(result["isValidatingPolicy"])
                    self.assertEqual(result["policy"], policy["metadata"]["name"])
                    self.assertEqual(result["kind"], "Pod")
                    expected_names.extend(result["resources"])
                    expected_results.append(result["result"])
                self.assertCountEqual(expected_names, fixture_names)
                self.assertIn("pass", expected_results)
                self.assertIn("fail", expected_results)
                self.assertIn("skip", expected_results)
                self.assertCountEqual(
                    test["resources"],
                    [str(p.relative_to(folder)).replace("\\\\", "/").replace("\\", "/")
                     for p in (folder / "fixtures").glob("*.yaml")],
                )

    def test_fixtures_cannot_schedule_by_default(self):
        for tier in TIERS:
            for path in (ROOT / tier / "fixtures").glob("*.yaml"):
                with self.subTest(path=path.name, tier=tier):
                    pod = read_yaml(path)
                    self.assertFalse(pod["spec"]["automountServiceAccountToken"])
                    self.assertEqual(pod["spec"]["nodeSelector"], {
                        "kyverno-tiered-lab.invalid/never-schedule": "true",
                    })
                    self.assertEqual(pod["spec"]["restartPolicy"], "Never")

    def test_no_active_trust_or_exception_objects(self):
        for path in ROOT.rglob("*.yaml"):
            for document in yaml.safe_load_all(path.read_text(encoding="utf-8")):
                if isinstance(document, dict):
                    self.assertNotIn(document.get("kind"), {
                        "PolicyException", "ImageValidatingPolicy",
                        "NamespacedImageValidatingPolicy", "Secret",
                    })
        template = ROOT / "examples/image-trust.yaml.example"
        self.assertTrue(template.exists())
        self.assertIn("REQUIRED_EXACT_SIGNING_WORKFLOW_SUBJECT", template.read_text())

    def test_workflow_has_read_only_authority_and_pinned_actions(self):
        # PyYAML's YAML 1.1 loader treats the key 'on' as boolean; no event mutation occurs here.
        workflow = read_yaml(ROOT / ".github/workflows/checks.yml")
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        for job in workflow["jobs"].values():
            for step in job["steps"]:
                if "uses" in step:
                    self.assertRegex(step["uses"], r"^[^@]+@[0-9a-f]{40}$")
                if step.get("uses", "").startswith("actions/checkout@"):
                    self.assertFalse(step["with"]["persist-credentials"])


if __name__ == "__main__":
    unittest.main()
