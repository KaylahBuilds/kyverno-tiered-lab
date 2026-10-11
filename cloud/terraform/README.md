# Optional Terraform cloud foundations

Choose [Azure AKS](aks/README.md) or [Amazon EKS](eks/README.md). These independent Terraform roots create **new, billable private-API sandbox clusters**; they do not adopt existing infrastructure. Use Terraform 1.9.8 or newer within the declared version range.

The same foundation examples are provided in both the Falco and Kyverno repositories. To run both tools on one cluster, create a foundation **once**, keep that foundation state in one location, and use each repository's separate `cloud/addons` state. Do not apply both copies of a foundation to the same cluster name. Already have an authorized disposable cluster? Skip infrastructure creation and follow [the add-on guide](../README.md).

| Decision | AKS example | EKS example |
| --- | --- | --- |
| Nodes | Three Ubuntu2404 amd64 VMs | Three AL2023 amd64 managed EC2 nodes |
| Authentication | Entra group, Azure RBAC, no local admin | Explicit IAM role access entry, no implicit creator admin |
| API | Private with private DNS | Private endpoint and scoped management CIDRs |
| Networking | Azure CNI overlay, Standard outbound load balancer | VPC CNI, private worker subnets, two NAT gateways |
| Required inputs | Subscription, tenant, admin group, region, supported version | Account, admin role, region/AZs, management CIDRs, supported version |

The roots label workers `security-lab=enabled`. Review node access, policy scope and capacity before installing either tool. A private endpoint does not create a VPN, management host or DNS forwarding: arrange those separately. The foundations intentionally do not create public application ingress.

## Validate without a cloud account

From the repository root:

```sh
terraform fmt -check -recursive cloud
terraform -chdir=cloud/terraform/aks init -backend=false
terraform -chdir=cloud/terraform/aks validate
terraform -chdir=cloud/terraform/aks test
terraform -chdir=cloud/terraform/eks init -backend=false
terraform -chdir=cloud/terraform/eks validate
terraform -chdir=cloud/terraform/eks test
```

Provider downloads need network access. All twelve foundation tests use mocked providers and plan only. They do not prove live permissions, quotas, version availability, private network reachability or cluster readiness.

Read the selected platform's full guide before filling in ignored local inputs or running an actual plan. Never commit credentials, kubeconfigs, populated tfvars, state or plans. No cloud apply runs in CI. Remove both tools' lab workloads and add-ons before destroying a shared foundation, while its private API remains reachable. Review and confirm destruction of the exact dedicated resources; idle clusters and networking keep accruing charges.

