resource "aws_security_group" "active_directory_management_instance" {
  name   = "mcgruff-active-directory-management-instance"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [module.vpc]
}

# resource "aws_vpc_security_group_ingress_rule" "active_directory_management_instance_ingress" {
#   security_group_id            = aws_security_group.active_directory_management_instance.id
#   from_port                    = 3389
#   to_port                      = 3389
#   ip_protocol                  = "tcp"
#   referenced_security_group_id = aws_security_group.ec2_instance_connect_endpoint.id
# }

resource "aws_iam_role" "active_directory_domain_admin" {
  name = "active-directory-domain-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ssm.amazonaws.com"
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
  tags = {
    Name = "active-directory-domain-admin"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforSSM" {
  role       = aws_iam_role.active_directory_domain_admin.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.active_directory_domain_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMDirectoryServiceAccess" {
  role       = aws_iam_role.active_directory_domain_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_instance_profile" "active_directory_domain_admin" {
  name = aws_iam_role.active_directory_domain_admin.name
  role = aws_iam_role.active_directory_domain_admin.name
}

# Give the policy attachments and IAM role a few seconds to replicate in AWS
resource "time_sleep" "wait_for_iam_role" {
  create_duration = "30s"
  depends_on = [
    aws_iam_role_policy_attachment.AmazonSSMManagedInstanceCore,
    aws_iam_role_policy_attachment.AmazonSSMDirectoryServiceAccess
  ]
}

data "aws_ssm_parameter" "jump_host_windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
}

resource "tls_private_key" "jump_host_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jump_host_key_pair" {
  key_name_prefix = "mcgruff-"
  public_key      = tls_private_key.jump_host_private_key.public_key_openssh
}

resource "local_sensitive_file" "jump_host_private_key_file" {
  filename             = "${aws_key_pair.jump_host_key_pair.key_name}.pem"
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.jump_host_private_key.private_key_pem
}

resource "aws_instance" "jump_host" {
  ami                    = data.aws_ssm_parameter.jump_host_windows_ami.value
  instance_type          = "t2.small"
  subnet_id              = module.vpc.private_subnets[0]
  iam_instance_profile   = aws_iam_role.active_directory_domain_admin.name
  vpc_security_group_ids = [aws_security_group.active_directory_management_instance.id]
  key_name               = aws_key_pair.jump_host_key_pair.key_name
  get_password_data      = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-DOC
    <powershell>
    Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server
    </powershell>
  DOC

  tags = {
    Name = "mcgruff-active-directory-jump-host"
  }

  depends_on = [aws_security_group.active_directory_management_instance]
}

data "aws_ssm_document" "AWS-JoinDirectoryServiceDomain" {
  name = "AWS-JoinDirectoryServiceDomain"
}

resource "aws_ssm_association" "AWS-JoinDirectoryServiceDomain" {
  name = data.aws_ssm_document.AWS-JoinDirectoryServiceDomain.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jump_host.id]
  }

  parameters = {
    directoryId    = aws_directory_service_directory.directory.id
    directoryName  = aws_directory_service_directory.directory.name
    dnsIpAddresses = sort(aws_directory_service_directory.directory.dns_ip_addresses)[0]
  }

  # Enable, and provide a (pre-existing) S3 bucket name to view output logs
  # output_location {
  #   s3_bucket_name = "changme"
  #   s3_key_prefix  = "mcgruff-ssm-command-logs"
  # }
}

output "Active_Directory_Management_Instance_Private_Key_FIle_Name" {
  value = "${aws_key_pair.jump_host_key_pair.key_name}.pem"
}
