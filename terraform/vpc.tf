resource "aws_cloudformation_stack" "aws_cft_stack" {
  name = "application-cft-stack"
  template_body = file("./amazon-eks-vpc-private-subnets.yaml")
  parameters = {
    VpcBlock = "192.168.0.0/16",
    PublicSubnet01Block = var.PublicSubnet01Block
    PublicSubnet02Block = var.PublicSubnet02Block
    PrivateSubnet01Block = var.PrivateSubnet01Block
    PrivateSubnet02Block = var.PrivateSubnet02Block
  }
}