resource "aws_security_group" "allow_rds" {
  name   = "mcgruff-allow-rdp"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mcgruff-allow-rdp"
  }

  depends_on = [module.vpc]
}

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

resource "aws_instance" "jump_host" {
  ami                    = data.aws_ssm_parameter.jump_host_windows_ami.value
  instance_type          = "t2.small"
  subnet_id              = data.aws_subnets.vpc_public_subnets.ids[0]
  iam_instance_profile   = aws_iam_role.active_directory_domain_admin.name
  vpc_security_group_ids = [aws_security_group.allow_rds.id]
  key_name               = var.key_pair_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "active-directory-jump-host"
  }

  depends_on = [aws_security_group.allow_rds]
}

resource "aws_ssm_document" "join_domain" {
  name          = "join-domain-${aws_directory_service_directory.directory.id}"
  document_type = "Command"
  content       = <<DOC
{
    "schemaVersion": "1.0",
    "description": "Automatic Domain Join Configuration",
    "runtimeConfig": {
        "aws:domainJoin": {
            "properties": {
                "directoryId": "${aws_directory_service_directory.directory.id}",
                "directoryName": "${aws_directory_service_directory.directory.name}",
                "dnsIpAddresses": [
                     "${sort(aws_directory_service_directory.directory.dns_ip_addresses)[0]}",
                     "${sort(aws_directory_service_directory.directory.dns_ip_addresses)[1]}"
                  ]
            }
        }
    }
}
DOC

  tags = {
    Name = "join-domain-${aws_directory_service_directory.directory.id}"
  }

  depends_on = [aws_directory_service_directory.directory]
}

resource "aws_ssm_association" "join_domain" {
  name = aws_ssm_document.join_domain.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jump_host.id]
  }

  # Enable and provide an (existing) S3 bucket name to view output logs
  output_location {
    s3_bucket_name = "mcgruff-terraform-204a97d0-11b6-4b10-8ed7-85eec2885eaa "
    s3_key_prefix  = "mcgruff-ssm-command-logs"
  }

  depends_on = [aws_ssm_document.join_domain]
}

data "aws_ssm_document" "AWS-RunPowerShellScript" {
  name = "AWS-RunPowerShellScript"
}

resource "aws_ssm_association" "install_rsat_tools" {
  name                             = data.aws_ssm_document.AWS-RunPowerShellScript.name
  wait_for_success_timeout_seconds = 240

  parameters = {
    commands = "Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server"
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jump_host.id]
  }

  # Enable and provide an (existing) S3 bucket name to view output logs
  output_location {
    s3_bucket_name = "mcgruff-terraform-204a97d0-11b6-4b10-8ed7-85eec2885eaa "
    s3_key_prefix  = "mcgruff-ssm-command-logs"
  }

  depends_on = [
    aws_instance.jump_host,
    aws_ssm_association.join_domain
  ]
}

output "Active_Directory_management_instance_details" {
  value = {
    Public_DNS                    = "${aws_instance.jump_host.public_dns}"
    Credential_SecretManager_Name = aws_secretsmanager_secret.active_directory_credential.name
  }
}
