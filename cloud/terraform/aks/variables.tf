variable "cluster_name" {
  description = "Unique sandbox cluster/resource name; use a different name per repository if deploying both."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.cluster_name))
    error_message = "Use 3-30 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "subscription_id" {
  description = "Explicit target Azure subscription ID; never store credentials in this input."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id)) && var.subscription_id != "00000000-0000-0000-0000-000000000000"
    error_message = "Supply the target subscription UUID, not the all-zero placeholder."
  }
}

variable "tenant_id" {
  description = "Explicit Entra tenant for the subscription and administrator group."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id)) && var.tenant_id != "00000000-0000-0000-0000-000000000000"
    error_message = "Supply the real Entra tenant UUID."
  }
}

variable "admin_group_object_id" {
  description = "Existing Entra group object ID to receive scoped AKS RBAC Cluster Admin and Cluster User roles."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.admin_group_object_id)) && var.admin_group_object_id != "00000000-0000-0000-0000-000000000000"
    error_message = "Supply the object UUID of an existing, reviewed administrator group."
  }
}

variable "location" {
  description = "Azure public-cloud region; check AKS version, Ubuntu2404 and VM availability first."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,29}$", var.location))
    error_message = "Use the Azure region identifier, such as eastus2."
  }
}

variable "kubernetes_version" {
  description = "Required region-supported AKS version, also compatible with Ubuntu2404 and the selected Helm chart."
  type        = string
  validation {
    condition     = can(regex("^1\\.[0-9]{2}(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "Use a supported AKS 1.xx or exact 1.xx.y version; verify regional support first."
  }
}

variable "node_vm_size" {
  description = "Reviewed 4-vCPU/16-GiB amd64 baseline, never ARM, virtual nodes or a burstable system pool."
  type        = string
  default     = "Standard_D4s_v5"
  validation {
    condition     = contains(["Standard_D4s_v5", "Standard_D4as_v5"], var.node_vm_size)
    error_message = "Select a reviewed 4-vCPU amd64 VM size."
  }
}

variable "vnet_cidr" {
  description = "Non-overlapping 10.x.0.0/16 VNet; must not overlap pod/service or connected network ranges."
  type        = string
  default     = "10.43.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vnet_cidr)) && can(regex("^10\\.[0-9]{1,3}\\.0\\.0/16$", var.vnet_cidr)) && !contains(["10.244.0.0/16", "10.96.0.0/16"], var.vnet_cidr)
    error_message = "Use a non-overlapping 10.x.0.0/16, excluding reserved pod/service ranges."
  }
}
