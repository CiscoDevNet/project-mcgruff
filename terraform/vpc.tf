resource "aws_vpc" "application_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "application_vpc"
  }
}

resource "aws_internet_gateway" "application_igw" {
  vpc_id = aws_vpc.application_vpc.id

  tags = {
    Name = "application_igw"
  }
}

resource "aws_subnet" "private-us-east-1a" {
  vpc_id            = aws_vpc.application_vpc.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                                      = "private-us-east-1a"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/application_cluster" = "owned"
  }
}

resource "aws_subnet" "private-us-east-1b" {
  vpc_id            = aws_vpc.application_vpc.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "us-east-1b"

  tags = {
    "Name"                                      = "private-us-east-1b"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/application_cluster" = "owned"
  }
}

resource "aws_subnet" "public-us-east-1a" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "public-us-east-1a"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/application_cluster" = "owned"
  }
}

resource "aws_subnet" "public-us-east-1b" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "public-us-east-1b"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/application_cluster" = "owned"
  }
}

resource "aws_eip" "application_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "application_nat_eip"
  }
}

resource "aws_nat_gateway" "application_nat_gateway" {
  allocation_id = aws_eip.application_nat_eip.id
  subnet_id     = aws_subnet.public-us-east-1a.id

  tags = {
    Name = "application_nat_gateway"
  }

  depends_on = [aws_internet_gateway.application_igw]
}

resource "aws_route_table" "application_private_route_table" {
  vpc_id = aws_vpc.application_vpc.id
  tags = {
    Name = "application_private_route_table"
  }
}

resource "aws_route" "application_private_route" {
  route_table_id = aws_route_table.application_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.application_nat_gateway.id
}

resource "aws_route_table" "application_public_route_table" {
  vpc_id = aws_vpc.application_vpc.id

  tags = {
    Name = "application_public_route_table"
  }
}

resource "aws_route" "application_public_route" {
  route_table_id         = aws_route_table.application_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.application_igw.id
}

resource "aws_route_table_association" "private-us-east-1a" {
  subnet_id      = aws_subnet.private-us-east-1a.id
  route_table_id = aws_route_table.application_private_route_table.id
}

resource "aws_route_table_association" "private-us-east-1b" {
  subnet_id      = aws_subnet.private-us-east-1b.id
  route_table_id = aws_route_table.application_private_route_table.id
}

resource "aws_route_table_association" "public-us-east-1a" {
  subnet_id      = aws_subnet.public-us-east-1a.id
  route_table_id = aws_route_table.application_public_route_table.id
}

resource "aws_route_table_association" "public-us-east-1b" {
  subnet_id      = aws_subnet.public-us-east-1b.id
  route_table_id = aws_route_table.application_public_route_table.id
}
