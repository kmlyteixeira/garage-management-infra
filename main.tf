locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "platform"
  })

  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = local.common_tags
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Tier = "public" })
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = var.availability_zones[count.index]
  tags              = merge(local.common_tags, { Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(local.common_tags, { Tier = "public" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
  tags   = local.common_tags
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id
  depends_on    = [aws_internet_gateway.main]
  tags          = local.common_tags
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = merge(local.common_tags, { Tier = "private" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name}-eks-cluster"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_security_group" "api" {
  name        = "${local.name}-api"
  description = "Security group for API workloads"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Application traffic from EKS load balancer or gateway"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/${var.environment}/platform/vpc-id"
  type  = "String"
  value = aws_vpc.main.id
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/platform/private-subnet-ids"
  type  = "String"
  value = jsonencode(aws_subnet.private[*].id)
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.project_name}/${var.environment}/platform/cluster-name"
  type  = "String"
  value = aws_eks_cluster.main.name
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "workload_security_group_ids" {
  name  = "/${var.project_name}/${var.environment}/platform/workload-security-group-ids"
  type  = "String"
  value = jsonencode([aws_security_group.eks_cluster.id])
  tags  = local.common_tags
}

resource "aws_s3_bucket" "service_state" {
  bucket_prefix = "${var.project_name}-terraform-state-"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "service_state" {
  bucket = aws_s3_bucket.service_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "service_state" {
  bucket = aws_s3_bucket.service_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "service_state" {
  bucket                  = aws_s3_bucket.service_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ssm_parameter" "service_state_bucket" {
  name  = "/${var.project_name}/${var.environment}/platform/service-state-bucket"
  type  = "String"
  value = aws_s3_bucket.service_state.bucket
  tags  = local.common_tags
}
