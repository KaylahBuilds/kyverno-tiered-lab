# Optional disposable-cluster walkthrough

This exercise observes Audit versus Deny through Kubernetes admission. It assumes you already have an isolated **disposable** cluster named `kind-kyverno-lab` in kubeconfig, with Kyverno **1.19.1**, its current ValidatingPolicy CRD, and healthy admission/reporting components. Review the [official installation and compatibility guidance](https://kyverno.io/docs/installation/installation/) when preparing that cluster. For optional AKS/EKS infrastructure and controller installation, use [the Terraform cloud guide](../cloud/README.md) first. Credentials stay outside Git.

All commands below explicitly select the context; substitute only the name of your own disposable cluster. Never substitute a production context. Run from the repository root. These are manual, reviewable commands, not an automated deployment script.

The exercise uses three namespaces and three named policies. Only the Tier 1 Pod is persisted, and it cannot schedule unless a node has the deliberately unusual never-schedule label. Tier 2 and Tier 3 requests use server-side dry runs.

## 1. Confirm the destination and fresh names

```sh
kubectl --context kind-kyverno-lab cluster-info
kubectl --context kind-kyverno-lab get deployments -n kyverno -o wide
kubectl --context kind-kyverno-lab get crd validatingpolicies.policies.kyverno.io
kubectl --context kind-kyverno-lab get namespaces kyverno-lab-tier1 kyverno-lab-tier2 kyverno-lab-tier3 --ignore-not-found
kubectl --context kind-kyverno-lab get validatingpolicies.policies.kyverno.io kyverno-lab-team-audit kyverno-lab-pod-security kyverno-lab-approved-images --ignore-not-found
kubectl --context kind-kyverno-lab get nodes -l kyverno-tiered-lab.invalid/never-schedule=true
```

The last three queries must find **no objects**. Stop if any lab namespace/policy already exists or any node has that selector label. Investigate ownership before proceeding; never adopt or delete an existing resource just because its name matches.

Confirm controller images are v1.19.1 and replicas are healthy. These checks do not establish availability under failure.

## 2. Create only the intended objects

```sh
kubectl --context kind-kyverno-lab create -f examples/namespaces.yaml
kubectl --context kind-kyverno-lab create -f tier-1-audit/policy.yaml
kubectl --context kind-kyverno-lab create -f tier-2-enforce/policy.yaml
kubectl --context kind-kyverno-lab create -f tier-3-governance/policy.yaml
kubectl --context kind-kyverno-lab wait --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=120s validatingpolicies.policies.kyverno.io/kyverno-lab-team-audit
kubectl --context kind-kyverno-lab wait --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=120s validatingpolicies.policies.kyverno.io/kyverno-lab-pod-security
kubectl --context kind-kyverno-lab wait --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=120s validatingpolicies.policies.kyverno.io/kyverno-lab-approved-images
```

If creation or readiness fails, stop and inspect the policy status and controller logs. Do not interpret an unrelated API, schema, permission, or connectivity error as a successful denial demonstration.

Policies are cluster-scoped objects with explicit namespace match conditions. Their validation scope is limited; controller and webhook configuration still deserve inspection. The namespace manifest also enables Restricted Pod Security Admission as an independent safety control.

## 3. Audit permits a policy violation

```sh
kubectl --context kind-kyverno-lab create -f tier-1-audit/fixtures/missing-team.yaml
kubectl --context kind-kyverno-lab get pod missing-team -n kyverno-lab-tier1
kubectl --context kind-kyverno-lab get policyreports.wgpolicyk8s.io -n kyverno-lab-tier1 -o yaml
```

Expected admission outcome: `pod/missing-team created`, despite its missing team label. It should remain Pending because no node matches the selector. Do not remove the selector or label a node to make it run.

The report query may initially be empty. Wait for the configured report/background processing to run, then repeat the read. Look for policy `kyverno-lab-team-audit`, the `missing-team` resource, and a failing evaluation. A missing report can indicate delay, reporting configuration, exclusions, or a controller problem; it is not proof the Pod passed.

These default v1.19.1 examples use the PolicyReport CRD. If you intentionally enabled a different report backend, use that backend's documented query and record the configuration alongside the evidence.

## 4. Deny a workload defect without starting a workload

```sh
kubectl --context kind-kyverno-lab create --dry-run=server -f tier-2-enforce/fixtures/hardened.yaml
kubectl --context kind-kyverno-lab create --dry-run=server -f tier-2-enforce/fixtures/writable-root.yaml
```

The first request should succeed as a server dry run. The second should return a nonzero status and a Kyverno denial naming `kyverno-lab-pod-security` and the container-hardening requirement.

A dry run exercises the admission chain without persisting a Pod or pulling an image. Client-side dry runs do not exercise that chain. A different rejection, such as RBAC denial or an unavailable API server, is not the expected policy result.

The native tests cover additional violations. Do not create their privileged or host-access fixtures in a real cluster. Some also violate Pod Security Admission, which can mask the Kyverno-specific result.

## 5. Govern an image reference without claiming image trust

```sh
kubectl --context kind-kyverno-lab create --dry-run=server -f tier-3-governance/fixtures/approved.yaml
kubectl --context kind-kyverno-lab create --dry-run=server -f tier-3-governance/fixtures/registry-lookalike.yaml
kubectl --context kind-kyverno-lab create --dry-run=server -f tier-3-governance/fixtures/mutable-tag.yaml
```

The first should be accepted; the last two should be denied by `kyverno-lab-approved-images`.

The accepted reference points to a reserved invalid domain with an all-zero synthetic digest. Acceptance therefore proves only that the reference satisfied the local CEL rule. No image was fetched and no signature or provenance was verified.

## 6. Inspect the live boundary

```sh
kubectl --context kind-kyverno-lab get validatingpolicies.policies.kyverno.io kyverno-lab-team-audit kyverno-lab-pod-security kyverno-lab-approved-images -o yaml
kubectl --context kind-kyverno-lab get validatingwebhookconfigurations -o yaml
```

Inspect the actual match scope, readiness, timeout, namespace exclusions, and webhook `failurePolicy`. Do not take down a shared admission controller to simulate failure. Outage/recovery testing requires a separately planned disposable environment.

These policies do not validate controller templates because auto-generation is explicitly disabled. An accepted Deployment is not proof that the Pods it generates will be admitted.

## 7. Exact named cleanup

Only run this after confirming the objects were created by this walkthrough and no other work has been placed in the lab namespaces. Namespace deletion deletes everything in those namespaces and is not recoverable from this repository.

```sh
kubectl --context kind-kyverno-lab delete pod missing-team -n kyverno-lab-tier1 --ignore-not-found
kubectl --context kind-kyverno-lab delete validatingpolicies.policies.kyverno.io kyverno-lab-team-audit kyverno-lab-pod-security kyverno-lab-approved-images --ignore-not-found
kubectl --context kind-kyverno-lab delete namespaces kyverno-lab-tier1 kyverno-lab-tier2 kyverno-lab-tier3 --ignore-not-found
```

This cleanup names only the three policies, three namespaces, and one persisted Pod. It does not uninstall Kyverno, remove CRDs, or change unrelated namespaces. If you separately activated a derivative of the trust template, its owner must separately review and remove the exact named policy.

Record the CLI version, cluster version, installed controller revision, exact commit, and observed results when documenting a live run. Do not publish raw kubeconfig, tokens, or unsanitized cluster reports.
