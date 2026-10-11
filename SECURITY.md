# Security and operational scope

This is a public teaching repository containing synthetic fixtures. It is not a production policy bundle or a compliance assessment.

## Run safely

- Use the CLI first. Its native tests do not require Kubernetes credentials or execute container images.
- Use only an explicitly selected disposable cluster for the optional cluster walkthrough.
- Create fresh named namespaces. Do not reuse namespaces containing other workloads.
- Never recursively apply all repository YAML. Negative resources are fixtures; test declarations are CLI-only; the signature example is incomplete.
- Keep the never-schedule node selector on fixtures. The live exercise tests admission and reporting, not workload execution.
- Review availability and fail-open/fail-closed settings before adapting policies. Fail-closed admission can prevent legitimate changes while Kyverno is unavailable.
- Do not grant application authors broad PolicyException write access or a label-controlled bypass.

## Credentials and evidence

Do not commit kubeconfigs, access tokens, private signing keys, cloud credentials, registry passwords, customer data, or raw production reports. Keep generated output under ignored `artifacts*/` directories and redact before sharing.

If a credential leaks, revoke or rotate it; removing it from Git is not remediation. A signature-verification policy uses public trust material and identity constraints, not private signing credentials.

## Reporting a problem

Use GitHub's private vulnerability reporting for this repository if the feature is available. Otherwise, contact the maintainer through the public profile and request a private reporting channel before sharing sensitive material. Public issues are appropriate for nonsensitive documentation errors and synthetic fixture failures. Do not include secrets or live exploit evidence in a public issue.

No security response SLA or support commitment is implied by this lab.
