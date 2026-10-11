# Amazon Elastic Kubernetes Service example

Use an existing authorized disposable EKS cluster or the optional [Terraform foundation](../terraform/eks/). This example targets **EC2 managed Linux nodes with AWS VPC CNI**. It is not a tested EKS Fargate, Auto Mode, hybrid-node or custom-CNI recipe.

## 1. Establish the exact destination

Use an AWS SSO/assumed-role session, not committed access keys. Verify account, region and cluster ARN. The authorized principal must also have EKS/Kubernetes access; successful AWS CLI authentication alone does not grant permission to create CRDs, cluster roles or webhooks.

The profile needs three Ready Linux nodes carrying `security-lab=enabled`, as provided by the optional foundation. On an existing disposable cluster ask its operator to label three specifically reviewed nodes; do not change arbitrary shared nodes.

From the repository root in Bash, set the real region and cluster name after reviewing them:

```sh
export AWS_REGION=YOUR_REGION
aws sts get-caller-identity
aws eks describe-cluster --name YOUR_LAB_CLUSTER --region "$AWS_REGION" \
  --query 'cluster.{name:name,arn:arn,version:version,endpoint:endpoint,network:resourcesVpcConfig}'
mkdir -p .tools
export LAB_KUBECONFIG="$PWD/.tools/kubeconfig-eks"
test ! -e "$LAB_KUBECONFIG" # stop and inspect an existing file
aws eks update-kubeconfig --name YOUR_LAB_CLUSTER --region "$AWS_REGION" \
  --kubeconfig "$LAB_KUBECONFIG" --alias kyverno-eks-lab
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab cluster-info
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab get nodes -l security-lab=enabled -o wide
helm --kubeconfig "$LAB_KUBECONFIG" --kube-context kyverno-eks-lab list --all-namespaces
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab get namespace kyverno --ignore-not-found
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab get crd validatingpolicies.policies.kyverno.io --ignore-not-found
```

Stop on pre-existing Kyverno resources rather than adopting them. For context generation see [AWS's EKS kubeconfig guide](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html).

## 2. Review the webhook network path

Kyverno admission uses an internal Service on TCP 443 targeting its Pods on **TCP 9443** in this pinned chart. The EKS control plane must reach that destination. Check cluster/control-plane and node security groups, any security groups for Pods, NACLs, routing and network policy—not only workstation-to-API connectivity. Permit the necessary path from the **cluster control-plane security group**, not `0.0.0.0/0`. Return traffic and controller access to the API/DNS also matter. The add-on does not mutate existing security groups.

The profile deliberately leaves `hostNetwork: false`. A custom CNI may make Pod addresses unreachable from the control plane; diagnose that topology separately. Do not add host networking or open a broad port range as an unexplained workaround. If a separately reviewed design needs host networking, also review DNS policy, port conflicts, node exposure and security groups, and test it as a new profile.

`kube-system` is excluded so a fail-closed workload policy cannot block VPC CNI bootstrap when nodes/controllers are being recovered. This is a documented [EKS operability concern](https://kyverno.io/docs/installation/platform-notes/#notes-for-eks-users). See also [EKS security-group requirements](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html).

## 3. Install, then inspect the live boundary

```sh
export TF_VAR_platform=eks
export TF_VAR_kubeconfig_path="$LAB_KUBECONFIG"
export TF_VAR_kube_context=kyverno-eks-lab
terraform -chdir=cloud/addons init
terraform -chdir=cloud/addons plan
# Only after approving the exact cluster and proposed changes:
terraform -chdir=cloud/addons apply
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab rollout status deployment/kyverno-admission-controller -n kyverno --timeout=300s
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab get deployments,pods,pdb -n kyverno -o wide
kubectl --kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab get validatingwebhookconfigurations,mutatingwebhookconfigurations -o yaml
```

Inspect images, replica placement, webhook targets, TLS/CA configuration, namespace exclusions, timeouts and failure policies before the [tier exercises](../README.md#tier-1--2--3-on-either-cloud). Use `--kubeconfig "$LAB_KUBECONFIG" --context kyverno-eks-lab` on every request. A timeout or unreachable webhook is not a successful denial; require the policy's named validation message.

## 4. ECR trust is not the node's pull permission

For a cloud-registry Tier 3 derivative, use your exact account, region and repository prefix, for example the shape `ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/platform/APP@sha256:FULL_DIGEST`. Restrict the whole prefix instead of accepting any ECR registry. Update native fixtures to cover another account, another region, another repository, a mutable tag and malformed digest before server-dry-run testing.

The standard synthetic policy needs no ECR credentials and this add-on attaches no AWS role. Node image-pull permissions do not automatically establish Kyverno's registry identity. For a later ImageValidatingPolicy, design a dedicated short-lived workload identity for each relevant Kyverno controller, constrain repository read access, review any token API permission that inherently requires a wildcard resource, and verify cross-account repository policy independently. Select an exact signing issuer/subject and test unsigned, tampered and wrong-signer cases. Do not paste ECR passwords into Helm values or Terraform state.

Use [AWS ECR IAM documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/security_iam_id-based-policy-examples.html) and [Kyverno image validation](https://kyverno.io/docs/policy-types/image-validating-policy/). [The inactive image-trust template](../../examples/image-trust.yaml.example) is a starting point, not proof of signature verification or provenance.

## Cleanup and remaining proof

The shared named cleanup removes only this walkthrough's objects. Keep the control plane and authentication available while reviewing/removing the add-on, and destroy a foundation only after confirming exclusive ownership. Live webhook admission/recovery, report durability, network paths and ECR authentication remain staging checks beyond Terraform mocks and Helm rendering.
