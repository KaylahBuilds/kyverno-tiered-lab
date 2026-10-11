variable "platform" {
  description = "Select the reviewed AKS or EKS profile. Does not create a cluster."
  type        = string
  validation {
    condition     = contains(["aks", "eks"], var.platform)
    error_message = "platform must be aks or eks."
  }
}

variable "kubeconfig_path" {
  description = "Path to a local, uncommitted kubeconfig using short-lived CLI authentication."
  type        = string
  validation {
    condition     = length(trimspace(var.kubeconfig_path)) > 0
    error_message = "Provide an explicit local kubeconfig path."
  }
}

variable "kube_context" {
  description = "Exact disposable-cluster context to prevent implicit current-context deployment."
  type        = string
  validation {
    condition     = length(trimspace(var.kube_context)) > 0
    error_message = "Provide an explicit, non-empty kubeconfig context."
  }
}
