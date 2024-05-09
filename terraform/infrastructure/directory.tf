data "aws_subnets" "vpc_public_subnets" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  tags = {
    Name = "public"
  }
  depends_on = [module.vpc]
}

resource "random_string" "active_directory_password" {
  length           = 16
  override_special = "_!$"
}

resource "aws_secretsmanager_secret" "active_directory_credential" {
  name_prefix = "active-directory-credential-"
}

resource "aws_secretsmanager_secret_version" "active_directory_credential" {
  secret_id     = aws_secretsmanager_secret.active_directory_credential.id
  secret_string = jsonencode({
    user_name = "Admin"
    password = aws_directory_service_directory.directory.password
  })
}

resource "aws_directory_service_directory" "directory" {
  name       = var.domain_name
  short_name = var.vpc_name
  password   = random_string.active_directory_password.result
  edition    = "Standard"
  type       = "MicrosoftAD"
  # enable_sso = true

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = data.aws_subnets.vpc_public_subnets.ids
  }
}



