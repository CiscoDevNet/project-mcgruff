resource "aws_db_instance" "application_database" {
  allocated_storage    = 100
  availability_zone    = "us-east-1a"
  db_name              = "bitnami_opencart"
  engine               = "mariadb"
  engine_version       = "10.11"
  instance_class       = "db.t3.micro"
  username             = "administrator"
  password             = "Cisco!123"
  parameter_group_name = "default.mariadb10.11"
  skip_final_snapshot  = true
}
