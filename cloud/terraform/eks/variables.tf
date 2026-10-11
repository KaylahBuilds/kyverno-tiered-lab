variable "cluster_name" {
  description = "Unique sandbox cluster/resource name; use a different name per repository if deploying both."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.cluster_name))
    error_message = "Use 3-30 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "Commercial AWS region. Check EKS version and EC2 capacity before applying."
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[1-9]$", var.region))
    error_message = "Supply a commercial AWS region such as us-east-2."
  }
}

variable "aws_account_id" {
  description = "Explicit target account; provider refuses credentials for another account."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id)) && var.aws_account_id != "000000000000"
    error_message = "Supply the real 12-digit target account ID, not the sample placeholder."
  }
}

variable "admin_principal_arn" {
  description = "Existing, reviewed IAM role ARN in the target account; never an STS session or account root."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_+=,.@/-]+$", var.admin_principal_arn)) && startswith(var.admin_principal_arn, "arn:aws:iam::${var.aws_account_id}:role/")
    error_message = "Use an existing IAM role ARN from aws_account_id, not a user, root or STS session ARN."
  }
}

variable "admin_ipv4_cidrs" {
  description = "Narrow CIDRs for an already routed, private-connected management runner/VPN. This does not create connectivity."
  type        = set(string)
  validation {
    condition = length(var.admin_ipv4_cidrs) > 0 && alltrue([
      for cidr in var.admin_ipv4_cidrs :
      can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 24, false)
    ])
    error_message = "Supply at least one IPv4 CIDR with a /24 or narrower prefix; never 0.0.0.0/0."
  }
}

variable "kubernetes_version" {
  description = "Required supported EKS minor version (for example 1.35 only if currently offered in your region)."
  type        = string
  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "Use a supported EKS minor in 1.xx form; check regional availability first."
  }
}

variable "availability_zones" {
  description = "Exactly two distinct standard availability zones in region, with chosen instance capacity."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(toset(var.availability_zones)) == 2 && alltrue([for az in var.availability_zones : can(regex("^${var.region}[a-z]$", az))])
    error_message = "Supply two distinct standard AZ names from region."
  }
}

variable "vpc_cidr" {
  description = "Non-overlapping RFC1918 10.x.0.0/16 address space; verify against your connected networks."
  type        = string
  default     = "10.42.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("^10\\.[0-9]{1,3}\\.0\\.0/16$", var.vpc_cidr))
    error_message = "Use a non-overlapping 10.x.0.0/16 CIDR."
  }
}

variable "instance_type" {
  description = "Reviewed amd64 4-vCPU/16-GiB baseline; check regional availability. Not Graviton or Fargate."
  type        = string
  default     = "m6i.xlarge"
  validation {
    condition     = contains(["m6i.xlarge", "m6a.xlarge", "m7i.xlarge"], var.instance_type)
    error_message = "Choose one of the reviewed 4-vCPU x86 instance types."
  }
}
