resource "aws_directory_service_directory" "directory" {
  name     = "directory.mcgruff.com"
  password = "Cisco123!"
  size     = "Small"

  vpc_settings {
    vpc_id     = aws_vpc.vpc.id
    subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  }

  tags = {
    Project = "foo"
  }
}