module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.vpc_name

  azs = var.aws_availability_zones

  cidr            = var.vpc_cidr
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  enable_dns_support      = true

  public_subnet_tags = {
    "Name"                   = "public"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "Name"                            = "private"
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name                                        = var.vpc_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
