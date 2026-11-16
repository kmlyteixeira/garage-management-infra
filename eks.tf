resource "aws_eks_cluster" "main" {
  name     = "${local.name}-eks"
  role_arn = var.eks_cluster_role_arn
  version  = var.eks_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  tags = local.common_tags
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_instance_type]
  disk_size       = 50

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.common_tags
}
