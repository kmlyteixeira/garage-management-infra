variable "project_name" {
  type    = string
  default = "garage-management"
}

variable "environment" {
  type    = string
  default = "development"

  validation {
    condition     = contains(["development", "homologacao", "producao"], var.environment)
    error_message = "environment must be development, homologacao or producao."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "eks_version" {
  type    = string
  default = "1.35"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway to reduce non-production cost. Use false for production resilience."
  type        = bool
  default     = true
}

variable "admin_principal_arn" {
  description = "Optional IAM principal granted EKS admin access."
  type        = string
  default     = null
  nullable    = true
}

variable "auth_lambda_function_arn" {
  description = "ARN of the deployed authentication Lambda."
  type        = string
  default     = null
  nullable    = true
}

variable "api_origin_url" {
  description = "Deprecated public origin URL. Prefer api_listener_arn with a VPC Link."
  type        = string
  default     = null
  nullable    = true
}

variable "api_listener_arn" {
  description = "ARN of the internal load balancer listener serving the Kubernetes API."
  type        = string
  default     = null
  nullable    = true
}

variable "vpc_link_subnet_ids" {
  description = "Private subnet IDs for the API Gateway VPC Link."
  type        = list(string)
  default     = []
}

variable "vpc_link_security_group_ids" {
  description = "Security groups for the API Gateway VPC Link elastic network interfaces."
  type        = list(string)
  default     = []
}

variable "jwt_issuer" {
  description = "JWT issuer configured by the authentication service."
  type        = string
  default     = null
  nullable    = true
}

variable "jwt_audience" {
  description = "JWT audience accepted by protected API routes."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
