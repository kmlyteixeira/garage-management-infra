output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "api_security_group_id" {
  value = aws_security_group.api.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "api_gateway_endpoint" {
  value = try(aws_apigatewayv2_api.main[0].api_endpoint, null)
}

output "platform_parameter_prefix" {
  value = "/${var.project_name}/${var.environment}/platform"
}

output "service_state_bucket" {
  value = var.service_state_bucket
}
