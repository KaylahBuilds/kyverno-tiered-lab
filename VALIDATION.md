# Validation record and limits

Reviewed October 10, 2026.

## Executed locally

`python -m unittest discover -s tests -v` passed **5 structural tests** using the author's Windows virtual-environment Python with PyYAML 6.0.3 installed. On a fresh interpreter, first run `python -m pip install -r requirements-dev.txt`. They check namespace and action boundaries, fixture-to-expectation coverage, the unschedulable fixture guard, absence of active trust/exception/Secret objects, and read-only pinned CI actions.

These checks do **not** evaluate CEL, establish Kubernetes schema validity, or prove that Kyverno will accept or enforce a policy.

## Native engine evidence

The repository contains **26 native Kyverno expected outcomes** across three `kyverno-test.yaml` suites. The active CI workflow installs the official **v1.19.1** CLI after checking a reviewed release asset SHA-256, then runs:

```sh
.tools/kyverno test tier-1-audit tier-2-enforce tier-3-governance --detailed-results
```

The [initial native CI run](https://github.com/KaylahBuilds/kyverno-tiered-lab/actions/runs/38109821154) passed **26 tests with 0 failures** using Kyverno 1.19.1 at commit `81f5bee3adba5e18e5af46bd78f4e50ff779c82a`. The same run passed all 5 structural checks. These are native engine results from GitHub Actions; the local Windows environment had no Kyverno binary and could not resolve GitHub for a download.

Consult the [Policy checks workflow](https://github.com/KaylahBuilds/kyverno-tiered-lab/actions/workflows/checks.yml) for the result on any later commit you review. A pending or missing workflow run is not a passing validation result. No Kubernetes cluster was involved in this CI run.

The expected failures are intentional test cases. A successful suite means the engine agreed with all expected pass/fail/skip outcomes.

## Cloud validation and remaining limits

### Cloud validation suite

The AKS/EKS extension adds Terraform 1.9.8 schema validation and **16 mocked plan tests**: six for AKS, six for EKS and four for the Kyverno Helm add-on. Pins are AzureRM 5.9.0, AWS 6.68.0 and Helm provider 3.1.1. Provider initialization downloads public packages; mocked provider operations do not authenticate to a cloud or Kubernetes API.

Four additional source checks cover platform settings, install pins, explicit context selection and configuration boundaries. Helm 3.22.0 renders checksum-pinned chart 3.9.1 / Kyverno v1.19.1 for both platforms using Kubernetes 1.33.0 API capabilities. The checks inspect actual controller images, replicas, placement, disruption budgets, feature flags, CRDs, internal services and the ConfigMap used to reconcile webhooks. They do **not** prove that live webhooks were reconciled or retained by AKS Admission Enforcer.

Consult the [commit-specific workflow runs](https://github.com/KaylahBuilds/kyverno-tiered-lab/actions/workflows/checks.yml) for pass/fail results on the revision you review. Mock plans and Helm output do not replace the live cloud acceptance checklist.

### Remaining live checks

- Installing Kyverno or creating a Kubernetes cluster.
- Real AWS/Azure plans/applies, identity authorization, regional Kubernetes availability, quotas, private API/DNS routing, node startup, upgrade, billing or infrastructure teardown.
- Live admission, webhook timeout/outage recovery, controller auto-generation, or ephemeral-container subresource updates.
- Background scans, report persistence, reporting configuration, or API-server defaulting.
- Registry/image pulls or authenticated signature/attestation verification.
- PolicyException creation, matching, authorization, automatic expiry, or removal.
- Production rollout, organizational settings, required reviews, or branch protection.

The live walkthrough is a manual integration exercise, not a recorded live test. The image-trust template is inactive and unvalidated. Tier 3's synthetic digest/reference checks are not proof of signatures or provenance.

## Version and artifact provenance

Official release: [Kyverno v1.19.1](https://github.com/kyverno/kyverno/releases/tag/v1.19.1).

The installer pins `kyverno-cli_v1.19.1_linux_x86_64.tar.gz` to SHA-256 `b38228f367fc0fdc2b08f4c83ea50ac5f16c60ff8d62d76a66157c33c47b70ae`, read from [official release asset metadata](https://github.com/kyverno/kyverno/releases/expanded_assets/v1.19.1). This file records a reviewed download pin, not independent reproduction or verification of the upstream build.
