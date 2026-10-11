# Kyverno on Azure AKS and Amazon EKS

Use the same three learning tiers on either managed Kubernetes platform, with **Terraform for the cluster foundation and Helm release**. Policies remain readable YAML and are applied separately only after the controller is healthy. Terraform does not create credentials, apply the negative fixtures, or connect CI to either cloud.

| Stage | Azure | AWS | Authority required |
| --- | --- | --- | --- |
| Optional new lab | [AKS foundation](terraform/aks/) | [EKS foundation](terraform/eks/) | Human-approved cloud provisioning; creates billable resources. |
| Existing healthy cluster | [AKS walkthrough](aks/README.md) | [EKS walkthrough](eks/README.md) | Explicit kubeconfig/context; network and Kubernetes access. |
| Controller installation | [Shared Terraform root](addons/) with `platform = "aks"` | Same root with `platform = "eks"` | Creates Kyverno CRDs, cluster RBAC, controllers and webhooks. |
| Tier exercises | Audit, hardening, image-reference governance | Same policies and expected outcomes | Three named lab namespaces, bounded policy scope; no scheduled example workloads. |

The tested source contract is chart **3.9.1**, application **v1.19.1**, and Helm provider **3.1.1**. The chart metadata permits Kubernetes 1.25+, but that is not a current support guarantee: check the [Kyverno compatibility matrix](https://kyverno.io/docs/installation/installation/) and the chosen cloud's supported Kubernetes versions before creating a cluster. Render tests use Kubernetes 1.33.0 API capabilities; they do not prove a particular AKS/EKS version or kernel combination.

## Separate lifecycle boundaries

1. Review the chosen foundation's README, region/version availability, cost and identity requirements. Create it only if you need a new disposable cluster. An existing cluster skips this step.
2. Wait for the control plane and **at least three ready Linux nodes labeled `security-lab=enabled`**. These labels select dedicated lab capacity; the add-on does not label arbitrary nodes. The admission controller requires different hostnames for its three replicas. Three replicas on three nodes are not a tested availability SLO or zone-resilience guarantee.
3. Authenticate using the chosen walkthrough and inspect the exact context. Use a separate working copy/state for each cluster's `cloud/addons` root; **do not flip a deployed root from AKS to EKS**, which can leave a release behind or target the wrong cluster.
4. Initialize, plan, review and apply the add-on independently. A successful infrastructure plan does not mean a private API endpoint is reachable from your workstation or CI runner.
5. Inspect the live controller/webhooks, then run the named policy exercises. Never run `kubectl apply -f . --recursive`.

Keep state, plans, kubeconfig, cloud CLI caches and access tokens out of Git. A `sensitive` flag hides output, not state contents. Before real use, configure an access-controlled, encrypted remote backend with locking for each root and separate least-privilege deployment identities. The lab's read-only CI does not perform this setup or apply anything.

## What the install deliberately does

- Keeps `kube-system`, `kube-public`, `kube-node-lease`, and Kyverno outside resource-webhook scope. On EKS this protects VPC CNI bootstrap from a fail-closed admission dependency cycle. This is an operability tradeoff, not evidence those namespaces are compliant.
- Preserves the AKS webhook annotation explicitly. The chart already defaults it, but an important platform requirement should remain visible in the AKS profile.
- Runs three admission replicas with a two-available disruption budget, and two background, cleanup and reporting replicas. Requests/limits come from the pinned chart. Measure saturation, report lag, admission latency and node capacity before changing them.
- Leaves host networking off and services internal. No public load balancer, ingress, blanket firewall rule, cloud IAM binding, or registry password is installed.
- Disables automatic generation of Kubernetes-native admission policies for this teaching exercise so the webhook path remains observable. Existing policies disable workload-controller auto-generation too; accepting a Deployment does not prove its eventual Pods will pass.
- Leaves exception processing disabled and retains each policy's own Audit/Deny and failure settings. It does not globally force `failurePolicy: Ignore` to hide installation or networking problems.

These decisions are based on [Kyverno platform notes](https://kyverno.io/docs/installation/platform-notes/), [customization](https://kyverno.io/docs/installation/customization/), and the [versioned chart values](https://github.com/kyverno/kyverno/blob/v1.19.1/charts/kyverno/values.yaml).

## Tier 1 / 2 / 3 on either cloud

Follow the full [cluster walkthrough](../examples/CLUSTER-DEMO.md), substituting **every** `--context kind-kyverno-lab` with your explicit cloud context and adding `--kubeconfig "$LAB_KUBECONFIG"`. Keep the preflight ownership checks and namespace labels. The commands below summarize the expected evidence, not a shortcut around those checks.

| Tier | Request | Required evidence | What this does not prove |
| --- | --- | --- | --- |
| 1: Audit | Create `tier-1-audit/fixtures/missing-team.yaml` after the three named namespaces/policies are created. | Admission succeeds, Pod stays Pending due to the never-schedule selector, and the report identifies the missing team. | No enforcement; no reliable owner authentication. |
| 2: Enforce | Server-side dry-run `hardened.yaml`, then `writable-root.yaml` from `tier-2-enforce/fixtures/`. | First allowed; second denied specifically by `kyverno-lab-pod-security`. | RBAC/network/PSA errors are not a Kyverno test pass. |
| 3: Governance | Server-side dry-run `approved.yaml`, then `registry-lookalike.yaml` and `mutable-tag.yaml` from `tier-3-governance/fixtures/`. | Exact synthetic registry and digest shape accepted; unexpected prefix/tag rejected by `kyverno-lab-approved-images`. | Image existence, registry access, signature or provenance are not checked. |

Do not remove the never-schedule selector or apply privileged/host-access negative fixtures. The accepted Tier 3 image is intentionally synthetic. Each cloud guide explains how its registry changes the **next** trust exercise without pretending those synthetic tests prove ECR or ACR access.

## Verify before granting confidence

From the repository root:

```sh
terraform -chdir=cloud/addons init -backend=false
terraform -chdir=cloud/addons validate
terraform -chdir=cloud/addons test
python -m unittest discover -s cloud/tests -v
bash cloud/tests/render.sh
.tools/kyverno test tier-1-audit tier-2-enforce tier-3-governance --detailed-results
```

The first commands download public providers but mock all provider operations during tests. The render script needs Helm 3 and the existing Python development requirements; it verifies the chart archive SHA-256 from the [official index](https://github.com/kyverno/kyverno/blob/gh-pages/index.yaml), then checks rendered objects for both profiles. Rendered manifests may include generated TLS material, so the script keeps them in a temporary directory outside the repository and removes them afterwards.

These checks cannot establish live webhook reconciliation, the AKS Admission Enforcer's behavior, EKS network reachability, report persistence, identity bindings, fail-closed recovery, or registry signature verification. Record those as separate staging checks. See [VALIDATION.md](../VALIDATION.md) for executed evidence.

## Teardown is also a security change

Use exact named cleanup in the policy walkthrough first, only after verifying ownership. Remove any independently added cloud trust policies separately. Review the add-on destroy plan while the cluster is still reachable; uninstalling a controller removes admission protection. Do not destroy a shared cluster or delete Kyverno CRDs just to remove this lab. CRD deletion can destroy policy/report objects across namespaces, and Helm may deliberately retain CRDs. Only destroy an optional foundation after verifying it contains no other workloads or retained resources and reviewing its separate plan.
