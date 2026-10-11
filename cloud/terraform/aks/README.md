# Optional AKS sandbox foundation

This Terraform root creates a **new, billable sandbox** with standard AKS node pools. Skip it if you already have a suitable cluster; use the repository's cloud add-on example instead. The same foundation is mirrored in the Falco and Kyverno repositories: provision it **once**, then use separate add-on states to install either or both tools.

## What it creates

- A dedicated resource group, VNet, subnet and user-assigned cluster identity. Network Contributor is scoped to that VNet, not the subscription.
- A private API with system-managed private DNS and no public FQDN. Run Command is disabled, so it cannot substitute for a private management path.
- Managed Entra authentication and Azure RBAC, local administrator accounts disabled, and scoped RBAC Cluster Admin plus Cluster User assignments to your explicitly supplied existing Entra group.
- Three real Ubuntu 24.04 Linux/amd64 nodes using `Ubuntu2404`, each with four vCPUs and 16 GiB memory. No virtual nodes, serverless compute, ARM profile or AKS Automatic is configured.
- Azure CNI overlay and Azure network policy. A Standard Load Balancer provides outbound access for image pulls; a private API does **not** mean network-isolated or zero internet egress.

All workers have `security-lab=enabled` plus native Linux/amd64 labels. Three schedulable nodes support the Kyverno example's three admission replicas. This is lab capacity, not a workload benchmark or zone-resilient production design. One surge node may be added during upgrades. Validate actual Falco event volume and Kyverno admission load.

## Review before provisioning

1. Select a disposable subscription, its Entra tenant and an existing reviewed administrator **group object ID**. IDs are identifiers, not credentials, but populated configuration still belongs outside Git.
2. Authenticate through Azure CLI or a reviewed short-lived federated identity. The apply identity needs rights to create the resources and role assignments. The supplied admin group authorizes cluster access; it does not automatically authorize the Terraform deployer.
3. Pre-register required Azure resource providers (`Microsoft.ContainerService`, `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.ManagedIdentity`, `Microsoft.Storage`, `Microsoft.Authorization`, and any organization-required dependencies) with the subscription owner. AzureRM automatic registration is explicitly disabled; this example will not silently enable services across the subscription.
4. Check region-supported Kubernetes releases using `az aks get-versions --location REGION --output table`. Select a version supported by both **Ubuntu2404** and your pinned Helm chart. Consult the current AKS OS compatibility matrix. The synthetic `1.35` used in tests is not a promise of regional availability.
5. Check x86 VM SKU availability and quota for three `Standard_D4s_v5` or `Standard_D4as_v5` workers plus upgrade surge capacity. The allowlist intentionally excludes ARM/burstable alternatives.
6. Verify that your VNet does not overlap the fixed pod range `10.244.0.0/16`, service range `10.96.0.0/16`, or any connected network. The input guard rejects the obvious local overlaps; the module cannot discover all peered/on-premises networks.
7. Arrange a routed, private-connected management host plus private DNS before installing add-ons. This root does not create a VPN, Bastion, peerings, DNS forwarding or a CI runner.
8. Budget for three VMs, disks, the Standard AKS tier, load-balancer outbound resources, public IP/transfer and any management connectivity. Charges continue while the demo is idle.

A GitHub-hosted runner has no automatic network path to this API. Link/forward the AKS-managed private DNS zone to your management network as appropriate. Do not enable public access or use `az aks command invoke` as a substitute for a reviewed private deployment path.

## Validate and review the plan

From this directory:

```sh
terraform init -backend=false
terraform fmt -check
terraform validate
terraform test
```

The six mocked plan runs make no Azure calls and use synthetic UUIDs. They check the private API, Entra-only access, node baseline and input rejection. Installing the pinned provider requires registry access. These tests do not prove tenant membership, role propagation, private DNS, quota or live admission/runtime behavior.

Copy `terraform.tfvars.example` to ignored `terraform.tfvars`; replace every placeholder. Configure a separate encrypted, access-controlled backend with state locking before shared use. Keep credentials, kubeconfigs, state and saved plans out of Git; Terraform state may contain sensitive provider-returned attributes even when no credential output is declared.

```sh
terraform init
terraform plan -out=foundation.tfplan
# Review the subscription, Entra roles, resource scope and estimated cost.
# Only after your explicit approval:
terraform apply foundation.tfplan
```

CI does not deploy this environment. Keep this foundation and the Helm add-on in separate roots/states. Do not use `-target` to force a combined cluster/provider bootstrap.

## Connect, then install the add-on

Install Azure CLI, kubectl and kubelogin on the private-connected host. Authenticate as a member of the approved group. Inspect `terraform output kubeconfig_command` after provisioning and run the displayed command; never add `--admin`.

```sh
kubelogin convert-kubeconfig -l azurecli
kubectl --context YOUR_CLUSTER_NAME get nodes -L kubernetes.io/os,kubernetes.io/arch,security-lab
kubectl --context YOUR_CLUSTER_NAME auth can-i create clusterroles
```

Allow role-assignment propagation, then confirm all three workers are Ready and correctly labeled before following the cloud add-on instructions. Keep kubeconfig local and private. `node_resource_group` and `vnet_id` outputs help your platform team configure private management networking; there are deliberately no raw kubeconfig or token outputs.

## Deliberate lab tradeoffs

This is a standard, three-node system pool with workload scheduling allowed, not a dedicated production security node pool. Pod placement across three hostnames is not a guarantee of spread across three Azure availability zones. Adapt zonal placement, backups, service limits and operational ownership before production.

`Ubuntu2404` is explicit to avoid an ambiguous OS-family default. The actual managed node image/kernel can change through the configured `NodeImage` upgrade channel. Record the tested node image, kernel/BTF support and Falco readiness after every node-image upgrade; roll out through a canary cluster first.

No central Azure Monitor log pipeline is created here. Falco JSON stdout still needs a reviewed collection/retention destination, and Kubernetes audit logs require a separate AKS diagnostic-setting configuration. Neither the Helm install nor a private API proves that incidents will reach an operator.

## Cleanup

Destroy add-on states **first**, while the API and Entra authorization remain available. Check workload-created load balancers/disks separately. Run `terraform plan -destroy -out=destroy.tfplan` in this foundation directory, inspect the exact resource list and apply that plan only when approved. Verify AKS, the managed node resource group, identities, networking and disks are removed; deleting state does not delete billable resources.

## Sources

- [Private AKS clusters and DNS](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
- [AKS Entra authorization](https://learn.microsoft.com/en-us/azure/aks/entra-id-authorization)
- [AKS OS-version compatibility](https://learn.microsoft.com/en-us/azure/aks/upgrade-os-version)
- [AzureRM 5.9.0 AKS resource](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/kubernetes_cluster)
- [AzureRM resource-provider registration](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs#resource-provider-registrations)
- [Terraform provider mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)
