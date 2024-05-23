data "aws_subnets" "vpc_private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Name = "private"
  }
}

resource "aws_db_subnet_group" "database" {
  name = var.application_database_name

  subnet_ids = data.aws_subnets.vpc_private_subnets.ids

  tags = {
    Name = var.application_database_name
  }
}

resource "aws_security_group" "database" {
  name   = var.application_database_name
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = var.application_database_name
  }
}

resource "aws_vpc_security_group_egress_rule" "database_egress" {
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "database_ingress" {
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
}

resource "random_string" "mcgruff_database_password" {
  length           = 16
  override_special = "_!$"
}
resource "aws_secretsmanager_secret" "mcgruff_database_credential" {
  name_prefix = "mcgruff-database-credential-"
}

resource "aws_secretsmanager_secret_version" "mcgruff_database_credential" {
  secret_id = aws_secretsmanager_secret.mcgruff_database_credential.id
  secret_string = jsonencode({
    user_name = "Administrator"
    password  = random_string.mcgruff_database_password.result
  })
}

resource "aws_db_instance" "database" {
  identifier             = var.application_database_name
  storage_type           = "gp2"
  allocated_storage      = 10
  multi_az               = false
  availability_zone      = var.aws_availability_zones[0]
  db_name                = "wordpress"
  db_subnet_group_name   = aws_db_subnet_group.database.id
  engine                 = "mariadb"
  engine_version         = "10.11"
  instance_class         = "db.t3.micro"
  port                   = "3306"
  publicly_accessible    = false
  username               = "Administrator"
  password               = jsondecode(aws_secretsmanager_secret_version.mcgruff_database_credential.secret_string)["password"]
  parameter_group_name   = "default.mariadb10.11"
  apply_immediately      = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database.id]
  depends_on = [
    aws_db_subnet_group.database,
    aws_security_group.database
  ]
}

output "Secrets_Manager_Database_Credential_Name" {
  value = aws_secretsmanager_secret.mcgruff_database_credential.name
}
