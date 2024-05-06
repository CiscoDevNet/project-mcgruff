data "aws_subnets" "vpc_public_subnets" {
  filter {
    name = "vpc-id"
    values = [ module.vpc.vpc_id ]
  }

  tags = {
    Name = "public"
  }
}

resource "random_string" "directory_alias" {
  length = 10
  special = false
  upper = false
}

resource "aws_directory_service_directory" "directory" {
  name     = "directory.${var.domain_name}"
  password = "SuperSecretPassw0rd"
  edition  = "Standard"
  type     = "MicrosoftAD"
  alias = random_string.directory_alias.result
  enable_sso = true

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = data.aws_subnets.vpc_public_subnets.ids
  }
}
