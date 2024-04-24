variable "aws_cft_stack_name" {
  description = "Name of the CloudFormation stack for the main VPC"
}

variable "VpcBlock" {
  default = null
}

variable "PublicSubnet01Block" {
  default = null
}

variable "PublicSubnet02Block" {
  default = null
}

variable "PrivateSubnet01Block" {
  default = null
}

variable "PrivateSubnet02Block" {
  default = null
}