# No Kubernetes API or cloud credentials are used. Provider operations are mocked.
mock_provider "helm" {}

variables {
  platform        = "aks"
  kubeconfig_path = "/tmp/not-a-real-kubeconfig"
  kube_context    = "disposable-test-only"
}

run "aks_release_contract" {
  command = plan
  assert {
    condition     = helm_release.kyverno.version == "3.9.1" && helm_release.kyverno.namespace == "kyverno"
    error_message = "The reviewed chart and dedicated namespace must remain pinned."
  }
  assert {
    condition     = yamldecode(helm_release.kyverno.values[1]).config.webhookAnnotations["admissions.enforcer/disabled"] == "true"
    error_message = "AKS must explicitly opt Kyverno webhooks out of the Admission Enforcer."
  }
  assert {
    condition     = helm_release.kyverno.atomic && helm_release.kyverno.wait && helm_release.kyverno.wait_for_jobs
    error_message = "Installation must wait for readiness and roll back failed operations."
  }
}

run "eks_release_contract" {
  command = plan
  variables {
    platform = "eks"
  }
  assert {
    condition     = !yamldecode(helm_release.kyverno.values[1]).admissionController.hostNetwork
    error_message = "The standard EKS profile must not enable host networking."
  }
  assert {
    condition     = yamldecode(helm_release.kyverno.values[0]).admissionController.replicas == 3
    error_message = "Keep three admission replicas and review cluster capacity."
  }
  assert {
    condition     = !yamldecode(helm_release.kyverno.values[0]).features.forceFailurePolicyIgnore.enabled
    error_message = "The install must not globally bypass fail-closed policies."
  }
}

run "reject_implicit_context" {
  command = plan
  variables {
    kube_context = " "
  }
  expect_failures = [var.kube_context]
}

run "reject_implicit_kubeconfig" {
  command = plan
  variables {
    kubeconfig_path = ""
  }
  expect_failures = [var.kubeconfig_path]
}
