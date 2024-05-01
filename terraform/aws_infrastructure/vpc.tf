module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-${terraform.workspace}"

  azs = [
    "us-east-1a",
    "us-east-1b"
  ]

  cidr            = "10.0.0.0/16"
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  enable_dns_support      = true

  public_subnet_tags = {
    "Name"                   = "public-${terraform.workspace}"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "Name"                            = "private-${terraform.workspace}"
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name                                                   = "eks-${terraform.workspace}"
    "kubernetes.io/cluster/cluster-${terraform.workspace}" = "shared"
  }
}
