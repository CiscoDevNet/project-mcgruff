terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "5.42.0"
    }
  }
}

module "global_variables" {
  source = "../"
}
