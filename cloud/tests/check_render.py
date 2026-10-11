"""Check actual Helm output, not just that an override is written in a values file."""
import json
import sys
from pathlib import Path

import yaml


def check(platform, manifest):
    if platform not in {"aks", "eks"}:
        raise ValueError("Expected aks or eks")
    docs = [item for item in yaml.safe_load_all(manifest) if item]
    objects = {(d["kind"], d["metadata"]["name"]): d for d in docs}
    config = objects[("ConfigMap", "kyverno")]["data"]
    webhook_config = json.loads(config["webhooks"])
    # Supported by chart 3.9.1: a config object, not legacy list syntax.
    expressions = webhook_config["namespaceSelector"]["matchExpressions"]
    exclusions = set()
    for expression in expressions:
        if expression["key"] == "kubernetes.io/metadata.name" and expression["operator"] == "NotIn":
            exclusions.update(expression["values"])
    assert {"kube-system", "kube-public", "kube-node-lease", "kyverno"} <= exclusions
    if platform == "aks":
        assert json.loads(config["webhookAnnotations"])["admissions.enforcer/disabled"] == "true"

    expected_replicas = {"admission": 3, "background": 2, "cleanup": 2, "reports": 2}
    for component, replicas in expected_replicas.items():
        name = f"kyverno-{component}-controller"
        deployment = objects[("Deployment", name)]
        assert deployment["spec"]["replicas"] == replicas
        pod = deployment["spec"]["template"]["spec"]
        assert pod.get("hostNetwork", False) is False
        assert pod["nodeSelector"]["kubernetes.io/os"] == "linux"
        assert pod["nodeSelector"]["security-lab"] == "enabled"
        containers = pod["containers"] + pod.get("initContainers", [])
        for container in containers:
            assert container["image"].startswith("reg.kyverno.io/kyverno/")
            assert container["image"].endswith(":v1.19.1")
            assert container["securityContext"]["allowPrivilegeEscalation"] is False
        pdb = objects[("PodDisruptionBudget", name)]
        assert pdb["spec"]["minAvailable"] == (2 if component == "admission" else 1)

    admission = objects[("Deployment", "kyverno-admission-controller")]["spec"]["template"]["spec"]
    terms = admission["affinity"]["podAntiAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]
    assert terms[0]["topologyKey"] == "kubernetes.io/hostname"
    args = admission["containers"][0]["args"]
    assert "--generateValidatingAdmissionPolicy=false" in args
    assert "--forceFailurePolicyIgnore=false" in args
    assert "--autoUpdateWebhooks=true" in args
    assert "--webhookServerPort=9443" in args
    service = objects[("Service", "kyverno-svc")]
    assert service["spec"]["type"] == "ClusterIP"
    assert service["spec"]["ports"][0]["port"] == 443
    assert ("CustomResourceDefinition", "validatingpolicies.policies.kyverno.io") in objects
    assert not any(d["kind"] == "Ingress" for d in docs)
    assert not any(d["kind"] == "Service" and d["spec"].get("type") == "LoadBalancer" for d in docs)
    print(f"{platform}: chart render checked; live webhook reconciliation is NOT tested")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_render.py aks|eks rendered.yaml")
    check(sys.argv[1], Path(sys.argv[2]).read_text(encoding="utf-8"))
