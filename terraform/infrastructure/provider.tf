terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      # version = "5.42.0"
    }
  }

  backend "s3" {
    bucket = "mcgruff-terraform-204a97d0-11b6-4b10-8ed7-85eec2885eaa"
    key = "terraform-state-infrastructure"
    region = "us-east-1"
  }
}

