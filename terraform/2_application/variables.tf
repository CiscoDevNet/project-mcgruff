variable "aws_region" {
  description = "AWS region in which to create resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_availability_zones" {
  description = "Region availability zones in which to create resources."
  type        = list(string)
  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "vpc_name" {
  description = "Virtual Private Cloud name tag."
  type        = string
  default     = "mcgruff"
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_private_subnets" {
  description = "Private subnets to create in the VPC."
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

variable "vpc_public_subnets" {
  description = "Public subnets to create in the VPC."
  type        = list(string)
  default = [
    "10.0.4.0/24",
    "10.0.5.0/24",
  ]
}

variable "cluster_name" {
  description = "EKS Kubernetes cluster name."
  type        = string
  default     = "mcgruff-pod-host"
}

variable "k8s_namespace_name" {
  description = "Namespace to create/use in the K8s cluster."
  type        = string
  default     = "mcgruff"
}

variable "node_group_name" {
  description = "Application cluster node group name."
  type        = string
  default     = "mcgruff"
}

variable "application_database_name" {
  description = "MariaDB database name for the application."
  type        = string
  default     = "wordpress"
}

variable "domain_name" {
  description = "Domain name for the project (Active Directory / application).  This must be an existing, registered Route 53 domain in the AWS account."
  type        = string
}

