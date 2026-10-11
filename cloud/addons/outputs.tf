output "release_name" {
  description = "Helm release managed by this root."
  value       = helm_release.kyverno.name
}

output "namespace" {
  description = "Dedicated controller namespace, not an application namespace."
  value       = helm_release.kyverno.namespace
}

output "reviewed_application_version" {
  description = "Expected version from chart metadata; verify the actual live images separately."
  value       = "v1.19.1"
}
