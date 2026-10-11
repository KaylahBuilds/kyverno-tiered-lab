mock_provider "azurerm" {}

variables {
  cluster_name          = "security-lab-test"
  subscription_id       = "11111111-1111-1111-1111-111111111111"
  tenant_id             = "22222222-2222-2222-2222-222222222222"
  admin_group_object_id = "33333333-3333-3333-3333-333333333333"
  location              = "eastus2"
  kubernetes_version    = "1.35"
}

run "private_entra_linux_plan" {
  command = plan
  assert {
    condition     = azurerm_kubernetes_cluster.lab.private_cluster_enabled && !azurerm_kubernetes_cluster.lab.private_cluster_public_fqdn_enabled
    error_message = "AKS API must remain private, with no public FQDN."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.lab.local_account_disabled && azurerm_kubernetes_cluster.lab.azure_active_directory_role_based_access_control[0].azure_rbac_enabled && !azurerm_kubernetes_cluster.lab.run_command_enabled
    error_message = "Use Entra RBAC, disable local admin credentials and the run-command network bypass."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.lab.default_node_pool[0].node_count == 3 && azurerm_kubernetes_cluster.lab.default_node_pool[0].os_sku == "Ubuntu2404" && !azurerm_kubernetes_cluster.lab.default_node_pool[0].node_public_ip_enabled
    error_message = "Use three actual Ubuntu2404 Linux nodes without public IPs."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.lab.node_provisioning_profile[0].mode == "Manual" && azurerm_kubernetes_cluster.lab.node_provisioning_profile[0].default_node_pools == "None"
    error_message = "Keep explicitly managed VM node pools, not automatic node provisioning."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.lab.network_profile[0].network_plugin_mode == "overlay" && azurerm_kubernetes_cluster.lab.network_profile[0].network_policy == "azure"
    error_message = "Preserve the documented Azure CNI overlay baseline."
  }
  assert {
    condition     = azurerm_role_assignment.admin.role_definition_name == "Azure Kubernetes Service RBAC Cluster Admin" && azurerm_role_assignment.admin.principal_id == var.admin_group_object_id
    error_message = "Only the specified Entra group receives scoped cluster administration."
  }
}

run "reject_empty_subscription" {
  command = plan
  variables { subscription_id = "00000000-0000-0000-0000-000000000000" }
  expect_failures = [var.subscription_id]
}

run "reject_empty_tenant" {
  command = plan
  variables { tenant_id = "00000000-0000-0000-0000-000000000000" }
  expect_failures = [var.tenant_id]
}

run "reject_placeholder_admin" {
  command = plan
  variables { admin_group_object_id = "REPLACE_admin" }
  expect_failures = [var.admin_group_object_id]
}

run "reject_arm_nodes" {
  command = plan
  variables { node_vm_size = "Standard_D4ps_v5" }
  expect_failures = [var.node_vm_size]
}

run "reject_pod_network_overlap" {
  command = plan
  variables { vnet_cidr = "10.244.0.0/16" }
  expect_failures = [var.vnet_cidr]
}
