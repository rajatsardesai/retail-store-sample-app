module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Use the availability zones and subnets calculated in local values
  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # Merge common tags with specific tags for public and private subnets to ensure all resources are properly tagged for identification and management
  public_subnet_tags  = merge(local.common_tags, local.public_subnet_tags)
  private_subnet_tags = merge(local.common_tags, local.private_subnet_tags)

  # Configure NAT gateway settings based on the input variable
  enable_nat_gateway = true
  single_nat_gateway = var.enable_single_nat_gateway

  # Additional VPC settings
  create_igw = true

  # Enable DNS support and hostnames for the VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Manage default network ACL, route table, and security group to ensure they are tagged and identifiable
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default-nacl" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default-rt" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default-sg" }

  tags = local.common_tags
}

module "retail_app_eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # Configure both public and private endpoint access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # EKS auto mode configuration - simplued node management
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # KMS key configuration for encrypting Kubernetes secrets
  create_kms_key                  = true
  kms_key_description             = "EKS cluster ${local.cluster_name} KMS key for encrypting secrets"
  kms_key_deletion_window_in_days = 7

  # Enable EKS control plane logging for better visibility and troubleshooting
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.common_tags
}
