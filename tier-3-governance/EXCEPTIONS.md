# An exception needs an owner and an end

A PolicyException can cause a matching resource to skip a policy. It is a bypass that must be governed as carefully as the policy itself. Current Kyverno CEL policies use `policies.kyverno.io/v1` PolicyException resources with `policyRefs` and CEL `matchConditions`; older ClusterPolicy examples use a different API.

No active PolicyException is shipped, and the lab does not enable broad exception support in a cluster.

## Review record

Before an authorized exception is created, record:

| Field | Required decision |
| --- | --- |
| Owner and approver | Who accepts the risk and who can authorize the bypass? |
| Resource scope | Exact policy kind/name, namespace, resource kind/name, and relevant image digest; avoid wildcard scope. |
| Reason | Why remediation cannot precede the change and which control is being bypassed. |
| Duration | Creation time, UTC expiry, and a scheduled review/removal owner. |
| Compensating controls | What reduces exposure during the exception. |
| Remediation | A tracked work item and proof required to close the exception. |
| Evidence | Review, applied revision, admission/report outcome, and later removal. |

Do not trust an `expires-at` annotation as an enforcement mechanism. Kubernetes metadata alone does not automatically expire a Kyverno exception. Use a separately reviewed enforcement/removal mechanism, monitor its health, and verify the bypass stops working after the deadline. This repository supplies no automated expiry implementation.

## Test the lifecycle

A production exception change should have integration evidence for all of these states:

1. Without the exception, the targeted bad request is denied.
2. With the approved exception, exactly that request is exempted and identified in the report.
3. A neighboring name, namespace, policy, image, or identity remains denied.
4. A workload author cannot self-authorize a bypass through a label or an annotation.
5. After removal or enforced expiry, the same bad request is denied again.
6. Existing resources are reviewed and remediated; removing an exception does not retroactively stop a running Pod.

Limit exception-write access with RBAC and reviewed change control. Namespace placement alone is not a substitute for explicitly constrained matching. Confirm the scope semantics of the installed Kyverno version rather than assuming a familiar namespace name limits all effects.

Use `skip` evidence honestly: it means a control was not applied. Do not rewrite it as a passing compliance check. Avoid suppressing denied requests globally to solve one workload's issue.

Primary reference: [Kyverno policy exceptions](https://kyverno.io/docs/guides/exceptions/).
