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

resource "random_string" "mcgruff_active_directory_password" {
  length           = 16
  override_special = "_!$"
}

resource "aws_secretsmanager_secret" "mcgruff_active_directory_credential" {
  name_prefix = "mcgruff-active-directory-credential-"
}

resource "aws_secretsmanager_secret_version" "mcgruff_active_directory_credential" {
  secret_id = aws_secretsmanager_secret.mcgruff_active_directory_credential.id
  secret_string = jsonencode({
    user_name = "Admin"
    password  = random_string.mcgruff_active_directory_password.result
  })
}

resource "aws_directory_service_directory" "directory" {
  name       = var.domain_name
  short_name = var.vpc_name
  password   = jsondecode(aws_secretsmanager_secret_version.mcgruff_active_directory_credential.secret_string)["password"]
  edition    = "Standard"
  type       = "MicrosoftAD"
  # enable_sso = true

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = data.aws_subnets.vpc_public_subnets.ids
  }
}

output "Secrets_Manager_Active_Directory_Credential_Name" {
  value = aws_secretsmanager_secret.mcgruff_active_directory_credential.name
}


