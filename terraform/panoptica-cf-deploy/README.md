# Panoptica AWS Integration

This Terraform configuration automates the process of integrating AWS with Panoptica for enhanced cloud security and compliance monitoring.

## Requirements

Before you begin, ensure you have the following:

1. An AWS account
2. A Panoptica account (Sign up at https://www.panoptica.app/sign-up if you don't have one)
3. Terraform installed on your local machine
4. AWS CLI installed and configured with your AWS credentials
5. curl and jq installed on your system (used in the Terraform script for API calls, `apt install curl jq` or `brew install curl jq` on macos).

## Setup

## Configuration Details

The main Terraform configuration is in the `main.tf` file. Here are some key components:

- The AWS region is set to `us-west-1`. If you need to change this, modify line 21 and 73 in `main.tf`.
- The CloudFormation stack parameters are set in the `aws_cloudformation_stack` resource. If you need to modify these, they start around line 105 in `main.tf`.

### 1. Clone the Repository

Clone this repository to your local machine and navigate to the project directory.

### 2. Generate Panoptica API Key

1. Follow the guide at https://docs.panoptica.app/reference/rest-api-quick-start-guide to generate an API key for Panoptica.
2. Ensure that the API key has the necessary permissions as outlined in the guide.

### 3. Configure Terraform Variables

1. In the project directory, you'll find a file named `.tfvars.ex`. This is a template for your Terraform variables.
2. Create a copy of this file and name it `terraform.tfvars`:

   ```
   cp .tfvars.ex terraform.tfvars
   ```

3. Edit the `terraform.tfvars` file and replace the placeholder values with your actual values:

   ```
   account_name = "your-account-name"
   api_key      = "your-panoptica-api-key"
   ```

   - Replace `"your-account-name"` with the name you want to use for this AWS account integration.
   - Replace `"your-panoptica-api-key"` with the API key you generated in step 2.

## Usage

Once you've completed the setup, you can use Terraform to deploy the Panoptica AWS integration:

1. Initialize Terraform:

   ```
   terraform init
   ```

2. Review the planned changes:

   ```
   terraform plan
   ```

3. Apply the configuration:

   ```
   terraform apply
   ```

   When prompted, type `yes` to confirm the changes.

4. To destroy the resources when you're done:

   ```
   terraform destroy
   ```

   When prompted, type `yes` to confirm the destruction of resources.

## Troubleshooting

If you encounter any issues:

1. Ensure your AWS CLI is correctly configured with the right credentials.
2. Verify that your Panoptica API key has the correct permissions.
3. Check the Terraform and AWS provider versions in the `terraform` block at the beginning of `main.tf`.

For any persistent issues, please refer to the Panoptica documentation or contact Panoptica support.