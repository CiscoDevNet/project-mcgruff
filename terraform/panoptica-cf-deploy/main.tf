# Configure the required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
}

# Variables
variable "account_name" {
  description = "Name of the account/stack to be deployed"
  type        = string
}

variable "api_key" {
  description = "API Key for Panoptica authorization"
  type        = string
  sensitive   = true
}

# Generate a UUID for external_id
resource "random_uuid" "external_id" {}

# Local variables
locals {
  panoptica_api_base_url = "https://api.us1.console.panoptica.app/api"
  headers = {
    "accept"        = "application/json"
    "authorization" = var.api_key
    "Content-Type"  = "application/json"
  }
}

# Get initial Panoptica Infrastructure Security Posture Account Information
data "http" "get_initial_account_info" {
  url    = "${local.panoptica_api_base_url}/cspm/context"
  method = "GET"

  request_headers = local.headers
}

# Extract tenantID from the initial account info response
locals {
  initial_account_info_response = jsondecode(data.http.get_initial_account_info.response_body)
  tenant_id                     = local.initial_account_info_response.tenantID
}

# Create Panoptica AWS Integration
data "http" "create_integration" {
  url    = "${local.panoptica_api_base_url}/cspm/settings/onboarding/aws/create-or-update"
  method = "POST"

  request_headers = local.headers

  request_body = jsonencode({
    deploy_type          = "single"
    account_name         = var.account_name
    region               = "us-west-1"
    workload_scanning    = true
    serverless_scanning  = true
    data_classification  = false
    scanning_type        = "external"
    scanner_id           = ""
    external_id          = random_uuid.external_id.result
    status               = ""
    template_url         = "https://panoptica-public-lightspin-prod-1.s3.us-east-2.amazonaws.com/cloudformation/single_template.json"
    template_url_org     = "https://panoptica-public-lightspin-prod-1.s3.us-east-2.amazonaws.com/cloudformation/org_root_template.json"
    stack_name           = "Panoptica"
    account_id           = "460146075389"
    panoptica_account_id = "145875358567"
    lambda_name          = "PanopticaLambdaVerifier"
    topic_name           = "onboarding-status-lightspin-prod-1"
    bucket_name          = "https://panoptica-public-lightspin-prod-1.s3.us-east-2.amazonaws.com/cloudformation/org_child_template.json"
    id                   = 0
  })
}

# Extract account_id from the create_integration response or get it from the initial account info
locals {
  create_integration_response = jsondecode(data.http.create_integration.response_body)
  account_id = can(local.create_integration_response.account_id) ? local.create_integration_response.account_id : null
  
  # If account_id is null, try to find it in the initial account info
  fallback_account_id = local.account_id == null ? [
    for aws in local.initial_account_info_response.selectedGroup.aws :
    aws.id if aws.name == var.account_name
  ][0] : local.account_id

  # Use a default value if both methods fail
  final_account_id = coalesce(local.fallback_account_id, "unknown")
}

# Define the CloudFormation stack resource
resource "aws_cloudformation_stack" "panoptica_stack" {
  name = var.account_name

  template_url = "https://panoptica-public-lightspin-prod-1.s3.us-east-2.amazonaws.com/cloudformation/single_template.json"

  parameters = {
    AccountDisplayName       = var.account_name
    AccountId                = "460146075389"
    CVEScanEnabled           = "true"
    DataClassificationEnabled = "false"
    ExternalId               = random_uuid.external_id.result
    LambdaName               = "PanopticaLambdaVerifier"
    PanopticaAccountId       = "145875358567"
    ServerlessScanEnabled    = "true"
    TenantID                 = local.tenant_id
    TopicName                = "onboarding-status-lightspin-prod-1"
  }

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  tags = {
    Environment = "Production"
    Project     = "Panoptica"
  }
}

# Null resource to handle deletion
resource "null_resource" "delete_integration" {
  triggers = {
    stack_id     = aws_cloudformation_stack.panoptica_stack.id
    api_key      = var.api_key
    account_id   = local.final_account_id
    api_base_url = local.panoptica_api_base_url
    account_name = var.account_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get updated account info
      UPDATED_INFO=$(curl -s -X GET '${self.triggers.api_base_url}/cspm/context' \
        -H 'accept: application/json' \
        -H 'authorization: ${self.triggers.api_key}')
      
      echo "Updated Info: $UPDATED_INFO"
      
      # Extract env_id
      ENV_ID=$(echo $UPDATED_INFO | jq -r '.selectedGroup.aws[] | select(.id == ${self.triggers.account_id}) | .envID')
      
      echo "Extracted ENV_ID: $ENV_ID"
      
      if [ -z "$ENV_ID" ]; then
        echo "Error: ENV_ID is empty. Trying to extract using the account name..."
        ENV_ID=$(echo $UPDATED_INFO | jq -r '.selectedGroup.aws[] | select(.name == "${self.triggers.account_name}") | .envID')
        echo "Extracted ENV_ID using account name: $ENV_ID"
      fi

      if [ -z "$ENV_ID" ]; then
        echo "Error: ENV_ID is still empty. Exiting."
        exit 1
      fi
      
      # Delete integration
      RESPONSE=$(curl -s -X POST '${self.triggers.api_base_url}/cspm/settings/onboarding/aws/delete' \
        -H 'accept: application/json' \
        -H 'authorization: ${self.triggers.api_key}' \
        -H 'Content-Type: application/json' \
        -d "{\"account_id\":\"$ENV_ID\"}")
      
      echo "Delete Response: $RESPONSE"
      
      if [[ $RESPONSE != *"200"* ]]; then
        echo "Error: Delete operation failed. Response: $RESPONSE"
        exit 1
      fi
    EOT
  }

  depends_on = [aws_cloudformation_stack.panoptica_stack]
}

# Outputs
output "stack_id" {
  value = aws_cloudformation_stack.panoptica_stack.id
}

output "stack_name" {
  value = aws_cloudformation_stack.panoptica_stack.name
}

output "account_id" {
  value = local.final_account_id
}