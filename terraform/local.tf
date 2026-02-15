# local values and data sources for terraform

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  # generate a unique cluster name by appending a random string to the base name
  cluster_name = "${var.cluster_name}-${random_string.suffix.result}"

  #network configuration for the VPC module, using the first 3 availability zones and calculating subnets based on the provided CIDR block
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = "retail-store"
    ManagedBy   = "terraform"
    CreatedBy   = "Rajat Sardesai"
    Owner       = data.aws_caller_identity.current.user_id
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }

  # Tags specific to public and private subnets to ensure they are properly identified by Kubernetes for ELB provisioning
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
