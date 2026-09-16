# -----------------------------------------------------------------------------
# Amazon EKS Cluster & Managed Node Group
# -----------------------------------------------------------------------------

# 1. EKS Control Plane
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    # Control plane ENIs connect to both public and private subnets
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Control Plane Logging for Audit & Security
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]

  tags = {
    Name = var.cluster_name
  }
}

# -----------------------------------------------------------------------------
# 2. Managed Worker Node Group
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-managed-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  # Security Best Practice: Worker nodes are deployed strictly inside Private Subnets
  subnet_ids = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND" # Use "SPOT" for 70% cost savings in sandbox/testing
  disk_size      = 20          # 20 GB root volume per node

  labels = {
    role        = "worker"
    environment = var.environment
  }

  tags = {
    Name = "${var.cluster_name}-node"
  }

  # Ensure IAM policies are attached before creating nodes to prevent join failures
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
  ]
}
