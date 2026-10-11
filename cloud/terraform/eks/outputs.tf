output "cluster_name" {
  value = aws_eks_cluster.lab.name
}
output "region" {
  value = var.region
}
output "vpc_id" {
  value = aws_vpc.lab.id
}
output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}
output "kubeconfig_command" {
  description = "Run only from the private-connected host, authenticated as or able to assume the approved admin role."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name} --role-arn ${var.admin_principal_arn} --alias ${var.cluster_name}"
}
