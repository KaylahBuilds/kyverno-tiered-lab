# Terraform-managed Kyverno add-on

This root installs Kyverno into an **already healthy disposable cluster**. It is independent from the AKS/EKS foundation root and owns one release named `kyverno` in namespace `kyverno`. Stop if that release, namespace, Kyverno CRDs or another policy-engine installation already exists and investigate ownership; this is not an import or upgrade runbook.

Required tools: Terraform 1.9.8+, the provider's local cloud authentication helpers (`aws` for EKS or `az` and `kubelogin` for AKS), kubectl, and network access to the cluster API, chart repository and provider registry. No static tokens or client keys are passed into Terraform.

Required inputs have **no implicit context or kubeconfig defaults**:

```hcl
# An example only; use environment variables or an ignored local tfvars file.
platform        = "aks" # or "eks"
kubeconfig_path = "/absolute/local/path/to/kubeconfig-aks"
kube_context    = "kyverno-aks-lab"
```

Choose [AKS](../aks/README.md) or [EKS](../eks/README.md) for authentication and plan commands. `pathexpand` supports a user-supplied `~`, but CI tests do not read your actual kubeconfig.

The Helm release has an exact chart version, waits for resources/jobs, and uses atomic rollback on an installation or upgrade failure. Atomic rollback is not a substitute for understanding CRD upgrade semantics. Chart 3.9.1 is reviewed with v1.19.1 controller images. The Terraform Helm installation uses the versioned upstream repository; the separate render test also checks the archive digest. Neither setting verifies the container publisher's cryptographic signing identity.

The common values require three schedulable Linux nodes carrying `security-lab=enabled`. Do not reduce the admission replica count or remove the required anti-affinity merely to make a broken rollout appear healthy. Investigate capacity and scheduling first.

## Provider mock tests

```sh
terraform -chdir=cloud/addons init -backend=false
terraform -chdir=cloud/addons validate
terraform -chdir=cloud/addons test
```

Four plan-only mock runs exercise the two platform contracts and reject an empty kubeconfig path or context. They do not download a chart through the provider, call Kubernetes, prove authentication, or validate a Helm values schema. The independent native Helm render check covers the values-to-object mapping.

## Plan / apply boundary

Select **one** platform per isolated state and review `terraform plan` before manual application. No apply command is part of CI. Use a protected remote backend before real work; never put backend access keys in source or `-backend-config` files committed to Git. Explicit context selection prevents accidental fallback but does not certify that the context names the intended cloud account—check the endpoint, account/subscription and cluster identity too.

Before an authorized manual teardown, remove only the exercise's known policies/namespaces, then inspect a destroy plan from this add-on root. Keep the cluster alive until Helm cleanup completes. Do not add an automatic cleanup workflow with cluster-admin credentials.

Reference: [HashiCorp Helm provider 3.1.1](https://github.com/hashicorp/terraform-provider-helm/blob/v3.1.1/docs/index.md) and [release resource](https://github.com/hashicorp/terraform-provider-helm/blob/v3.1.1/docs/resources/release.md).
