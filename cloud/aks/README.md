# Azure Kubernetes Service example

Use an existing, explicitly authorized disposable AKS cluster or the optional [Terraform foundation](../terraform/aks/). The reviewed profile targets Linux VM-backed nodes. Windows nodes, virtual nodes, private-endpoint routing and custom policy/network integrations need their own validation.

## 1. Identity, networking and capacity first

Use Entra ID authentication with the least-privilege Kubernetes/AKS role needed for this cluster-wide controller installation. Do not use `--admin` to bypass an authorization problem. Your CLI subscription is a separate choice from the kubeconfig context: verify both. A private cluster requires a working private network/DNS path from this workstation; opening the API to the world is not the fix.

The optional foundation provides the selected lab node label. For an existing disposable cluster, have its operator deliberately label **three reviewed Linux nodes** `security-lab=enabled` after checking capacity; do not label every node indiscriminately.

Commands below run from the repository root in Bash. Replace the resource group and cluster name with the exact reviewed values; do not paste access tokens into files.

```sh
az login
az account show --query '{subscription:id,tenant:tenantId,name:name}'
az aks show --resource-group YOUR_LAB_RESOURCE_GROUP --name YOUR_LAB_CLUSTER \
  --query '{name:name,version:kubernetesVersion,fqdn:fqdn,private:privateFqdn}'
mkdir -p .tools
export LAB_KUBECONFIG="$PWD/.tools/kubeconfig-aks"
test ! -e "$LAB_KUBECONFIG" # stop if this local file already exists; inspect it
az aks get-credentials --resource-group YOUR_LAB_RESOURCE_GROUP --name YOUR_LAB_CLUSTER \
  --file "$LAB_KUBECONFIG" --context kyverno-aks-lab
kubelogin convert-kubeconfig --login azurecli --kubeconfig "$LAB_KUBECONFIG"
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab cluster-info
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab get nodes -l security-lab=enabled -o wide
helm --kubeconfig "$LAB_KUBECONFIG" --kube-context kyverno-aks-lab list --all-namespaces
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab get namespace kyverno --ignore-not-found
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab get crd validatingpolicies.policies.kyverno.io --ignore-not-found
```

Confirm at least three labeled Ready Linux nodes and that this lab would not take over another installation. An authentication or preflight failure is a stop condition. Follow [Azure kubelogin guidance](https://learn.microsoft.com/en-us/azure/aks/kubelogin-authentication) for your environment.

## 2. Plan the controller separately

```sh
export TF_VAR_platform=aks
export TF_VAR_kubeconfig_path="$LAB_KUBECONFIG"
export TF_VAR_kube_context=kyverno-aks-lab
terraform -chdir=cloud/addons init
terraform -chdir=cloud/addons plan
# Only after approving the exact cluster and proposed changes:
terraform -chdir=cloud/addons apply
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab rollout status deployment/kyverno-admission-controller -n kyverno --timeout=300s
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab get deployments,pods,pdb -n kyverno -o wide
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab get validatingwebhookconfigurations,mutatingwebhookconfigurations -o yaml
```

The [AKS values](values.yaml) set `config.webhookAnnotations["admissions.enforcer/disabled"]` to the **string** `"true"`. Inspect the actual Kyverno webhooks after reconciliation and confirm the annotation, namespace exclusions, service targets and failure settings. Checking only Helm values cannot prove that AKS has left the live webhooks intact. This opt-out does not disable all AKS admission controls. Source: [Kyverno's AKS platform note](https://kyverno.io/docs/installation/platform-notes/#notes-for-aks-users).

Then run the [three-tier cloud exercise](../README.md#tier-1--2--3-on-either-cloud) using `--kubeconfig "$LAB_KUBECONFIG" --context kyverno-aks-lab` for every request.

## 3. ACR makes image access and image trust separate tasks

For an ACR-based Tier 3 derivative, substitute an **exact reviewed login server and repository prefix** into the policy and add native positive/negative fixtures before admission testing. For example, the shape is `YOUR_REGISTRY.azurecr.io/platform/APP@sha256:FULL_DIGEST`; do not broadly allow every `*.azurecr.io` registry. A digest-shaped string still proves neither existence nor trust.

AKS kubelet identity pulling an application image is not the same identity as Kyverno fetching that image's signature/attestation. The supplied synthetic policies do not need ACR access and the Terraform example grants none. A future signature-verification exercise must establish a separately reviewed Kyverno identity with least-privilege registry read rights, exact issuer/signing subject, repository scope, protected workflow identity, and negative unsigned/wrong-issuer/wrong-repository cases. Keep [the inactive trust template](../../examples/image-trust.yaml.example) inactive until those decisions are made.

See [AKS–ACR authentication](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration) for pull authorization and [Kyverno private-registry image validation](https://kyverno.io/docs/policy-types/image-validating-policy/) for policy-side access. Do not assume `AcrPull` applies unchanged to an ABAC-enabled registry; use the role model documented for that registry mode.

## Evidence and teardown

Record actual cluster/version, node placement, healthy replicas, live webhook annotation, allowed/denied server-dry-run requests and resulting report. Native/mock CI is not that evidence. Follow the shared teardown order: named policies/namespaces, add-on while API access still works, then an optional foundation only if it is entirely yours. Never delete shared Kyverno CRDs as a shortcut.
