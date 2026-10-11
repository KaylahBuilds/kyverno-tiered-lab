# Optional EKS sandbox foundation

This Terraform root creates a **new, billable sandbox**, not an in-place change to an existing cluster. Skip it if you already have a suitable EKS cluster; use the repository's cloud add-on example instead. The same foundation is mirrored in the Falco and Kyverno repositories: provision it **once**, then use separate add-on states to install either or both tools.

## What it creates

- A dedicated IPv4 VPC and private node subnets across exactly two standard AZs.
- A private-only EKS API, an explicit IAM role access entry and scoped management CIDR rules. Cluster creation does not implicitly grant the creator Kubernetes administrator rights.
- Three on-demand 4-vCPU / 16-GiB amd64 managed EC2 nodes, AL2023, encrypted 50-GiB root disks, IMDSv2 required and response hop limit 1. These are **not Fargate, Auto Mode or Bottlerocket**.
- One NAT gateway and Elastic IP per AZ for node egress. Public subnet names do not mean the nodes or API are public.
- EKS control-plane logs with 14-day CloudWatch retention. These audit logs are separate from Falco's node syscall events.

All workers have `security-lab=enabled` in addition to Kubernetes' native Linux/amd64 labels. Three schedulable nodes support the Kyverno example's three admission replicas; this is a starting capacity estimate, not a performance guarantee. Test with your actual rule count, events, admission load and upgrade headroom. The max node-group size of four does not install an autoscaler.

## Review before provisioning

1. Use a disposable AWS **commercial-cloud** account and an existing approved IAM administrator role in that account. The account guard prevents accidental use of a different account. Do not use IAM users, account root or STS session ARNs as access-entry principals.
2. Authenticate with a short-lived AWS SSO/assumed-role session outside Terraform files. The apply identity needs permission to create the named resources and IAM roles, pass cluster/node roles, and create access entries. Bootstrap and Kubernetes administrator identities may be different.
3. Choose a supported EKS minor and check your Helm chart's supported Kubernetes range. Check available versions with `aws eks describe-cluster-versions --region REGION --version-status STANDARD_SUPPORT`. The synthetic `1.35` in unit tests is **not** a regional availability claim.
4. Check EC2 instance offerings, vCPU quotas and two-AZ capacity for the selected type. The allowed x86 list is deliberate; ARM requires a separately tested profile.
5. Review VPC CIDRs for overlap with every connected network. `admin_ipv4_cidrs` is a /24-or-narrower ingress allowlist, **not** a VPN or route. Arrange private connectivity and DNS resolution before deploying add-ons. No bastion, VPN, peering or CI runner is created here.
6. Budget for the EKS control plane, three EC2 instances, EBS, **two NAT gateways**, two public IPv4 addresses, logs and transfer. These resources accrue charges until destroyed, even when the demos are idle.

The private endpoint must be reachable from the Terraform add-on runner, Helm and kubectl. An ordinary GitHub-hosted runner cannot reach it without an explicitly designed private network path. Do not temporarily expose the API to `0.0.0.0/0` to work around missing connectivity.

## Validate and review the plan

From this directory:

```sh
terraform init -backend=false
terraform fmt -check
terraform validate
terraform test
```

`terraform test` uses a mocked AWS provider and plans only: no credentials, AWS calls, cluster or resources. It checks private APIs, explicit administrator access, node capacity/OS, encrypted disks and guard rejection. Provider installation requires registry access. Mocks cannot prove cloud permissions, availability, node startup or network connectivity.

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars` and replace every placeholder. Do not commit populated inputs. Configure a separate encrypted, access-controlled backend with state locking before shared use; backend authentication also stays outside the repository. Local state and saved plans can contain sensitive values.

```sh
terraform init
terraform plan -out=foundation.tfplan
# Read the entire plan and verify account, region, IAM grants and cost.
# Only after your explicit approval:
terraform apply foundation.tfplan
```

This repository's CI never runs apply. Do not apply this root and the Helm add-on in the same state or use `-target` to force provider initialization.

## Connect, then install the add-on

After the approved apply, inspect `terraform output kubeconfig_command`. Run the displayed AWS CLI command on your private-connected workstation/runner; it uses the specified administrator role and a named context. That role must be assumable by your current session. Never publish kubeconfig or tokens.

```sh
kubectl --context YOUR_CLUSTER_NAME get nodes -L kubernetes.io/os,kubernetes.io/arch,security-lab
kubectl --context YOUR_CLUSTER_NAME auth can-i create clusterroles
```

Confirm all three workers are Ready, Linux/amd64 and labeled before proceeding to the cloud add-on instructions. Any further node pools require the same label and the add-on's reviewed scheduling/security configuration.

## Deliberate lab tradeoffs

EKS bootstraps its default self-managed VPC CNI, kube-proxy and CoreDNS. Track, pin and update those add-ons through a dedicated lifecycle before production; this root does not pretend to govern their ongoing versions. The latest compatible AL2023 release is chosen by EKS at initial node creation, so record the resulting AMI release and kernel when testing Falco.

The VPC CNI policy is on the node role for this small sandbox. IMDSv2/hop-limit 1 limits ordinary pod metadata access, but host-network or node-privileged workloads can still reach node credentials. Falco has elevated node access. Before production, isolate CNI permissions using workload identity, audit the node role, separate trust boundaries, restrict egress, and define update/incident procedures.

The EKS-managed cluster security group's self rule allows node/control-plane communication including admission webhooks. Tightening it requires preserving the actual Kyverno webhook target ports, kubelet and DNS paths; a cluster that runs workloads but cannot invoke its webhook is not a successful validation.

## Cleanup

Destroy add-on states **first**, while the cluster and credentials still work. Review any workload-created cloud load balancers/volumes separately. In this foundation directory, run `terraform plan -destroy -out=destroy.tfplan`, review the exact resource list, then `terraform apply destroy.tfplan` only when approved. Confirm NAT gateways, EIPs, cluster, EC2 and log resources are gone; do not delete the state to simulate cleanup.

## Sources

- [EKS private API access](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)
- [EKS managed-node launch templates](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html)
- [EKS security-group requirements](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html)
- [AWS provider 6.68.0 EKS resource](https://registry.terraform.io/providers/hashicorp/aws/6.68.0/docs/resources/eks_cluster)
- [Terraform provider mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)
