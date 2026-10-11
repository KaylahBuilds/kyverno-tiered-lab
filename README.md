# Kyverno policy security: three practical tiers

**See the gap. Test the boundary. Govern the exception.**

Companion to [the Kyverno policy field note](https://kaylahbuilds.io/#/blog/kyverno-policy-security-tiers) by Kaylah Builds.

This repository teaches Kubernetes policy adoption through native Kyverno tests and an optional, bounded cluster exercise. These tiers are our learning progression, **not official Kyverno levels, a compliance certification, or a complete production baseline**.

| Tier | Question | Runnable policy | Remaining boundary |
| --- | --- | --- | --- |
| [1 — Audit](tier-1-audit/README.md) | Can a finding be assigned to an owner? | Report a missing or empty team label. | Audit does not reject a policy violation. A label is not authenticated ownership. |
| [2 — Enforce](tier-2-enforce/README.md) | Can an unsafe Pod enter this namespace? | Deny selected Linux workload risks; cover app, init, and ephemeral containers. | A small hardening example is not the complete Pod Security Standards or runtime defense. |
| [3 — Governance](tier-3-governance/README.md) | Which owners and image references are approved? | Deny unknown teams, unexpected registry paths, and mutable or malformed image references. | Registry and digest syntax do not verify signatures, image existence, or provenance. |

Each tier is isolated in its own lab namespace for comparison. Production adoption should retain earlier controls as scope expands; Tier 3 does not automatically apply Tier 2's policy to its namespace.

## Run the native policy tests

The reviewed CLI pin is **Kyverno v1.19.1**, released September 10, 2026. The lab uses the current `policies.kyverno.io/v1` **ValidatingPolicy** API and CEL expressions. These are different from Kubernetes `ValidatingAdmissionPolicy` and Kyverno's legacy `ClusterPolicy`. The legacy type is [deprecated in Kyverno 1.19 with removal planned for 1.20](https://kyverno.io/docs/guides/exceptions/).

The core test suite requires the CLI, but **no cluster, image pull, registry credentials, cloud account, or network lookup during policy evaluation**. All image references are fixture data.

From the repository root, on Linux x86_64:

```sh
bash scripts/install-cli.sh
.tools/kyverno test tier-1-audit tier-2-enforce tier-3-governance --detailed-results
```

The installer downloads the official release archive over HTTPS, checks its reviewed SHA-256 before extraction, and installs locally under ignored `.tools/`. It does not require sudo. The digest pin protects against unexpected archive changes; it is not a substitute for auditing upstream or verifying release signing identity.

On another platform, use the corresponding [official v1.19.1 CLI release asset](https://github.com/kyverno/kyverno/releases/tag/v1.19.1), check its checksum, and run:

```sh
kyverno version
kyverno test tier-1-audit tier-2-enforce tier-3-governance --detailed-results
```

Reviewed release asset checksums, checked October 10, 2026:

| Asset | SHA-256 |
| --- | --- |
| `kyverno-cli_v1.19.1_linux_x86_64.tar.gz` | `b38228f367fc0fdc2b08f4c83ea50ac5f16c60ff8d62d76a66157c33c47b70ae` |
| `kyverno-cli_v1.19.1_windows_x86_64.zip` | `fe329f8ec5cfb19d3776d6a9e568d9857e3bf2be6ed82c6feb12d4fa73b626b8` |

Source: [official release asset metadata](https://github.com/kyverno/kyverno/releases/expanded_assets/v1.19.1). Review the version and checksum together when updating.

### Read the result correctly

There are **26 expected policy outcomes**: 4 in Tier 1, 12 in Tier 2, and 10 in Tier 3. A test declaring `result: fail` succeeds when the policy actually rejects that fixture during evaluation. A test declaring `result: skip` succeeds when the namespace condition excludes the fixture. Test success means actual and expected outcomes agreed, including the deliberately bad cases.

An Audit policy can evaluate a resource as failing while still permitting the admission request. The native tests exercise validation logic; they do not prove webhook availability, API-server defaulting, report persistence, RBAC, or live admission behavior. See [VALIDATION.md](VALIDATION.md) for the evidence boundary.

For the supplemental repository guardrails:

```sh
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

These five Python checks parse YAML and check fixture coverage, namespace scope, read-only CI, and inactive trust examples. They **do not evaluate CEL** and are not a replacement for `kyverno test`.

## Optional cluster exercise

[The cluster walkthrough](examples/CLUSTER-DEMO.md) assumes an explicitly selected disposable cluster with Kyverno 1.19.1 installed and healthy. It creates three named lab namespaces and three policies, creates one intentionally unscheduled Audit Pod, and uses server-side dry runs for enforcement examples. It includes exact named cleanup.

Do not recursively apply this repository. Test manifests are CLI inputs, negative fixtures are intentional, and the trust example is incomplete. Do not deploy these examples into production.

## Azure AKS and Amazon EKS examples

[The cloud guide](cloud/README.md) adds two practical paths: [Azure AKS](cloud/aks/README.md) and [Amazon EKS](cloud/eks/README.md). Each walks through the same Audit, Enforce, and Governance progression with explicit cluster selection and bounded namespaces.

- Optional **Terraform foundations** create separate private-API sandbox clusters with real Linux workers. No shared cloud account or subscription is assumed.
- A separate **Terraform Helm add-on** installs Kyverno with cloud-specific configuration, three admission-controller replicas, and node-placement settings.
- Platform notes cover AKS Admission Enforcer, EKS webhook networking, protected system namespaces, ACR/ECR image-reference examples, recovery checks, and manual cleanup.

Use an existing authorized disposable cluster, or create one with the appropriate foundation root. Private API access requires a connected workstation or runner. Cloud resources are billable; no cluster is created by CI. Mocked Terraform tests and native Helm renders validate configuration, not live admission, IAM, networking, or image signatures.

## The failure modes matter

- **Audit versus Deny:** `validationActions: [Audit]` records a violation; `[Deny]` rejects a matching violating admission request.
- **Policy failure versus evaluation failure:** `failurePolicy: Fail` handles errors evaluating the policy and contributes to fail-closed admission behavior. Webhook outages and timeouts are also governed by the generated webhook's failure settings. Inspect those live settings; an offline test cannot establish them.
- **Background versus admission:** background evaluation finds problems in existing objects. It does not evict, rewrite, or repair them. Admission checks a submitted operation. Existing workloads need a remediation plan.
- **Controller templates versus Pods:** this lab deliberately disables controller auto-generation. Deployments can be accepted while their generated Pods are denied. Review and test controller coverage before broader adoption.
- **Exception versus compliance:** an exception can bypass a control. A skipped result is not evidence the workload satisfied the rule. Read [the exception lifecycle](tier-3-governance/EXCEPTIONS.md).

Tier 1 uses `failurePolicy: Ignore` for its visibility exercise; Tiers 2 and 3 use `Fail`. Do not generalize those choices to a production availability decision without testing failure and recovery.

## What CI can do

The active workflow downloads the checksum-pinned CLI, runs native tests and structural checks, validates the three Terraform roots with mocked providers, and renders the AKS/EKS Helm configurations. It has `contents: read`, does not persist checkout credentials, and grants no OIDC or deployment authority. Actions use full commit pins.

The [image-trust example](examples/image-trust.yaml.example) is an inactive `.yaml.example` file outside the workflow directory. It requires an exact trusted signing identity, issuer, and repository scope. It is a signature-verification starting point, **not a completed provenance policy** and not exercised by the default tests.

## Repository map

```text
tier-1-audit/          Audit policy, fixtures, native test manifest, walkthrough
tier-2-enforce/        Pod hardening policy, fixtures, native test manifest
tier-3-governance/     Owner/image-reference policy, tests, exception lifecycle
examples/             Scoped namespace manifest, cluster demo, inactive trust template
cloud/                AKS/EKS guides, Terraform foundations/add-on, render checks
scripts/              Verified local CLI installer
tests/                Structural repository guardrails
.github/workflows/    Read-only native test CI
VALIDATION.md         Executed checks and limits
SECURITY.md           Scope, disclosure, credentials, and operational boundaries
```

## Primary references

- [Kyverno CLI and native test semantics](https://kyverno.io/docs/subprojects/kyverno-cli/)
- [ValidatingPolicy and CEL](https://kyverno.io/docs/policy-types/validating-policy/)
- [ImageValidatingPolicy](https://kyverno.io/docs/policy-types/image-validating-policy/)
- [Policy exceptions](https://kyverno.io/docs/guides/exceptions/)
- [Installation and security versus operability](https://kyverno.io/docs/installation/installation/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
