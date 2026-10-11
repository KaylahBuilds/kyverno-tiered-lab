mock_provider "aws" {}

variables {
  cluster_name        = "security-lab-test"
  region              = "us-east-2"
  aws_account_id      = "111111111111"
  admin_principal_arn = "arn:aws:iam::111111111111:role/lab-admin"
  admin_ipv4_cidrs    = ["10.42.250.10/32"]
  availability_zones  = ["us-east-2a", "us-east-2b"]
  kubernetes_version  = "1.35"
}

run "private_standard_nodes" {
  command = plan
  assert {
    condition     = aws_eks_cluster.lab.vpc_config[0].endpoint_private_access && !aws_eks_cluster.lab.vpc_config[0].endpoint_public_access
    error_message = "Cluster API must remain private-only."
  }
  assert {
    condition     = aws_eks_cluster.lab.access_config[0].authentication_mode == "API" && !aws_eks_cluster.lab.access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "Only an explicitly reviewed access entry may grant administration."
  }
  assert {
    condition     = aws_eks_node_group.lab.ami_type == "AL2023_x86_64_STANDARD" && aws_eks_node_group.lab.scaling_config[0].min_size == 3
    error_message = "Use at least three actual AL2023 amd64 EC2 nodes."
  }
  assert {
    condition     = length(aws_nat_gateway.lab) == 2 && alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    error_message = "Nodes need private subnets and a per-AZ egress path."
  }
  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_tokens == "required" && aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Require IMDSv2 and restrict ordinary pod access to node credentials."
  }
  assert {
    condition     = one(aws_launch_template.nodes.block_device_mappings).ebs[0].encrypted
    error_message = "Node root volumes must be encrypted."
  }
  assert {
    condition     = contains(aws_eks_cluster.lab.enabled_cluster_log_types, "audit")
    error_message = "Enable control-plane audit logs."
  }
}

run "reject_world_management" {
  command = plan
  variables { admin_ipv4_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.admin_ipv4_cidrs]
}

run "reject_root_principal" {
  command = plan
  variables { admin_principal_arn = "arn:aws:iam::111111111111:root" }
  expect_failures = [var.admin_principal_arn]
}

run "reject_other_account_principal" {
  command = plan
  variables { admin_principal_arn = "arn:aws:iam::222222222222:role/lab-admin" }
  expect_failures = [var.admin_principal_arn]
}

run "reject_single_az" {
  command = plan
  variables { availability_zones = ["us-east-2a", "us-east-2a"] }
  expect_failures = [var.availability_zones]
}

run "reject_arm_nodes" {
  command = plan
  variables { instance_type = "m7g.xlarge" }
  expect_failures = [var.instance_type]
}
