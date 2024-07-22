terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "5.49.0"
    }
  }

  backend "s3" {
    bucket = "dstaudt-mcgruff-20240715"
    key    = "terraform-state-infrastructure"
    region = "us-east-1"
  }
}

