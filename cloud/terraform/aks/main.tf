locals {
  tags = { Project = var.cluster_name, Environment = "sandbox", ManagedBy = "Terraform" }
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.cluster_name}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]
}

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "${var.cluster_name}-control-plane"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

# Scoped to this dedicated VNet, not the subscription.
resource "azurerm_role_assignment" "network" {
  scope                = azurerm_virtual_network.lab.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "lab" {
  name                                = var.cluster_name
  location                            = azurerm_resource_group.lab.location
  resource_group_name                 = azurerm_resource_group.lab.name
  dns_prefix                          = var.cluster_name
  kubernetes_version                  = var.kubernetes_version
  sku_tier                            = "Standard"
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"
  role_based_access_control_enabled   = true
  local_account_disabled              = true
  run_command_enabled                 = false
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  node_os_upgrade_channel             = "NodeImage"
  tags                                = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }

  node_provisioning_profile {
    mode               = "Manual"
    default_node_pools = "None"
  }

  default_node_pool {
    name                        = "linux"
    temporary_name_for_rotation = "linuxrotate"
    vm_size                     = var.node_vm_size
    os_sku                      = "Ubuntu2404"
    node_count                  = 3
    auto_scaling_enabled        = false
    node_public_ip_enabled      = false
    vnet_subnet_id              = azurerm_subnet.nodes.id
    node_labels                 = { "security-lab" = "enabled" }
    os_disk_size_gb             = 64
    upgrade_settings {
      max_surge = "1"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.96.0.0/16"
    dns_service_ip      = "10.96.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  depends_on = [azurerm_role_assignment.network]
}

# Explicit scoped authorization. No built-in local admin kubeconfig or implicit
# cluster-creator admission rights are used by this example.
resource "azurerm_role_assignment" "admin" {
  scope                = azurerm_kubernetes_cluster.lab.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.admin_group_object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "kubeconfig" {
  scope                = azurerm_kubernetes_cluster.lab.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.admin_group_object_id
  principal_type       = "Group"
}
