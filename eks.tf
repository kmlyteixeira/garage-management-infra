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

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      access_config[0].bootstrap_cluster_creator_admin_permissions
    ]
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_x86_64_STANDARD"
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

  depends_on = [
    aws_nat_gateway.main,
    aws_route_table_association.private
  ]
}

resource "aws_eks_access_entry" "admin" {
  count             = var.enable_eks_admin_access && var.admin_principal_arn != null ? 1 : 0
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = var.admin_principal_arn
  type              = "STANDARD"
  kubernetes_groups = ["eks-admins"]
}

resource "kubernetes_cluster_role_binding_v1" "admin" {
  count = var.enable_eks_admin_access && var.admin_principal_arn != null ? 1 : 0

  metadata {
    name = "garage-management-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "eks-admins"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [aws_eks_access_entry.admin]
}
