# Tier 1 — Make policy gaps visible

The first exercise asks for a nonempty `team` label on Pods in `kyverno-lab-tier1`. It uses `validationActions: [Audit]`: a policy violation is observable without becoming an admission denial.

Run from the repository root:

```sh
.tools/kyverno test tier-1-audit --detailed-results
```

This uses the Linux installer from the root README. If you installed the pinned CLI on your PATH instead, substitute `kyverno` for `.tools/kyverno`.

| Fixture | Expected evaluation | Why |
| --- | --- | --- |
| `has-team` | pass | A nonempty owner label is present. |
| `missing-team` | fail | No team label exists. |
| `empty-team` | fail | The label exists but has no value. |
| `outside-scope` | skip | The Pod is outside the lab namespace. |

All four expected outcomes should make the **test** pass. A missing label still evaluates as a policy failure under Audit; the live API request is allowed. This distinction is essential when reading CLI output.

The policy enables background evaluation. In a live cluster, reports can expose existing violations when the reporting components are enabled and the resources are in scope. Reports arrive asynchronously. Neither background scans nor admission validation add the missing label.

Try changing a copy of `has-team.yaml` to use an empty value and predict the result before running the CLI. An ownership label is useful routing data, but anyone allowed to edit that field can claim a team. The next tier needs both policy tests and an operational plan.

Before moving toward denial, identify each finding's owner, measure the affected population, resolve false positives, and document what failure recovery looks like. The [optional live walkthrough](../examples/CLUSTER-DEMO.md) shows the Audit/Deny distinction without starting a workload.
