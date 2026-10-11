output "cluster_name" {
  value = azurerm_kubernetes_cluster.lab.name
}
output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}
output "vnet_id" {
  value = azurerm_virtual_network.lab.id
}
output "node_resource_group" {
  description = "AKS-managed node resources and system private DNS zone; needed when designing private runner connectivity."
  value       = azurerm_kubernetes_cluster.lab.node_resource_group
}
output "kubeconfig_command" {
  description = "Run from a connected network with private DNS; authenticate as a member of the approved Entra group. Never use --admin."
  value       = "az aks get-credentials --subscription ${var.subscription_id} --resource-group ${azurerm_resource_group.lab.name} --name ${var.cluster_name} --context ${var.cluster_name}"
}
