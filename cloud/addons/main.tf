# Run only after the cluster exists and its authentication/network path works.
# Keep this root/state separate from cloud/terraform/aks or cloud/terraform/eks.
provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.9.1"
  namespace        = "kyverno"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  max_history      = 5

  values = [
    file("${path.module}/values-common.yaml"),
    file("${path.module}/../${var.platform}/values.yaml"),
  ]
}
