# Tier 2 — Enforce a tested workload boundary

This policy uses `validationActions: [Deny]` on Pods in `kyverno-lab-tier2`. It demonstrates selected Linux hardening controls with explicit positive and negative fixtures.

```sh
.tools/kyverno test tier-2-enforce --detailed-results
```

This uses the Linux installer from the root README. If you installed the pinned CLI on your PATH instead, substitute `kyverno` for `.tools/kyverno`.

The policy rejects host network/PID/IPC namespaces and hostPath volumes. Every regular, init, and ephemeral container must explicitly set a positive numeric user, `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, a read-only root filesystem, dropped `ALL` capabilities with no additions, and `RuntimeDefault` seccomp. Privileged containers are rejected.

This deliberately requires container-level settings even when Kubernetes could inherit settings from a Pod. It is a small teaching contract, not a complete implementation of the Kubernetes Restricted Pod Security Standard. It does not cover every Windows or Linux concern, host ports, resource-abuse controls, network policy, admission identities, or runtime behavior.

| Fixture | Expected outcome |
| --- | --- |
| `hardened` | pass |
| `privileged`, `root-user`, `missing-security-context` | fail |
| `host-network`, `host-path` | fail |
| `writable-root`, `added-capability`, `unconfined-seccomp` | fail |
| `unsafe-init`, `unsafe-ephemeral` | fail |
| `outside-scope` | skip |

All 12 expectations should agree with the native engine. The unsafe ephemeral fixture represents a final Pod shape for offline evaluation; live ephemeral containers must be added through their dedicated subresource. Do not try to create that fixture as a normal Pod.

The policy explicitly matches `pods/ephemeralcontainers` updates, but the offline fixture does not test that API-server integration. Include a real subresource update in a separate disposable-cluster integration test before claiming that path is protected.

The [cluster demo](../examples/CLUSTER-DEMO.md) uses `writable-root` as a rejected server-side dry run. This is intentional: the lab namespace also enables Kubernetes Restricted Pod Security Admission, which could reject other unsafe fixtures before a Kyverno-specific denial is observable.

`failurePolicy: Fail` and `validationActions: [Deny]` serve different purposes. Deny handles a known violation; failure policy addresses evaluation errors and fail-closed behavior. A healthy policy engine, recovery procedure, appropriate namespace exclusions, and observed webhook configuration are operational requirements.

Controller auto-generation is disabled to keep the exercise scoped and predictable. A Deployment can be admitted even if its generated Pod is denied. Add separately tested controller-template coverage before production rollout.
