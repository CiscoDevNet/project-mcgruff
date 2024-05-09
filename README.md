# CiscoDevNet/project-mcgruff

## Overview

Reference cloud application deployment incorporating various Cisco security technology APIs.  Focuses on common real-world components and patterns, applying security best practices.

![Network architecture](images/network_architecture.png)

Test using:

* Ubuntu 22.04

* Terraform 1.8.3

* Kubectl 1.30.0

* Helm 3.14.4

## Application

A 'typical' containerized, client-server web application with internal REST API and access group use-cases for at least 3 classes of users (admin/employee/external-customer).

### Components

#### Application

* [AWS EKS](https://aws.amazon.com/eks/) (Kubernetes) - single pod/node/cluster.

* [Wordpress container](https://hub.docker.com/_/wordpress) as the sample web application.

* [AWS Relational Database Services (RDS)](https://aws.amazon.com/rds/) hosting MariaDB.

#### Network Infrastructure

* [AWS Virtual Private Cloud](https://aws.amazon.com/vpc/) for egress/ingress and standard network services (DNS).

* [AWS Cloud Compute](https://aws.amazon.com/ec2/) providing instance hosting EKS pods.

* [AWS Directory Services](https://aws.amazon.com/directoryservice/) providing Microsoft Active Directory.

Also using: AWS [IAM](https://aws.amazon.com/iam/) / [ACM](https://aws.amazon.com/certificate-manager/) / [Route 53](https://aws.amazon.com/route53/)

#### Security Products

* [Cisco Duo Single-Sign-On/Multi-factor Authentication](https://duo.com/)

* (Others TBD)

## Pre-Requisites

* **Amazon AWS admin account** - this must be a paid account.  It is **highly** recommended that this _not_ be a production account, and/or that it is based in an AWS region not used by any production resources.

   **Note:** This project creates AWS resources that will incur (modest) ongoing charges - be sure to perform the steps in [Cleanup AWS Resources](#cleanup-aws-resources) when they are no longer needed.

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installation - assumes [login credentials have been configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) and CLI commands can be executed against the target AWS account/region.

* [AWS Route 53](https://aws.amazon.com/route53/) registered domain, owned by the AWS admin account above.  This domain will be used for the web-site/MS-AD - required for integration with Cisco Duo SSO/MFA.

* [Kubectl](https://kubernetes.io/docs/tasks/tools/) installation.

* [Helm](https://helm.sh/docs/intro/install/) installation.

## Getting Started

1. Clone the repository and change into the directory:

   ```
   git clone https://github.com/CiscoDevNet/project-mcgruff
   cd project-mcgruff
   ```

1. Create a new instance connection key pair (i.e. named `mcgruff`) via **EC2/Network & Security/Key Pairs**.

   **Note:** be sure to download and save the associated `PEM` file, as you will need this to decrypt the AD management instance's admin password - i.e. for RDP access.

1. Create an S3 bucket - this will be used for Terraform state files.

   Update `terraform/infrastructure/provider.tf` and `terraform/infrastructure/provider.tf` S3 `backend` sections with your S3 bucker name.

1. Edit `/terraform/global.tfvars`.

   All values can be left commented/default except `domain_name` and `key_pair_name`, which must be provided.

1. First, create the infrastructure resources:

   **(First run only)
   ```
   terraform init
   ```

   ```
   cd terraform/infrastructure
   terraform apply -var-file="../global.tfvars"
   ```

   **Hint:** You can use `pv` to provide a running timed-elapsed: `terraform apply -var-file="../global.tfvars" | pv -t`

   Allow this to complete (approx. 35 minutes).

   Output will indicate the DNS name of the Active Directory management instance (for connection via RDP) and the  [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) name of the admin credentia:

   TBD EXAMPLE

   **Note:** an RDP session to the AD management instance's local machine Administrator account can be accomplished from the AWS console via **EC2/Instances/Instance/Connect**

1. Next, create resources and deploy the application:

   **(First run only)**
   ```
   terraform init
   ```

   ```
   cd terraform/application
   terraform apply -var-file="../global.tfvars"
   ```

   Allow this to complete (approx. 10 minutes).

   Output will provide the URL for the running application:

   TBD EXAMPLE

1. Output from the application deployment will indicate the application URL, based on the provided domain name, e.g.: `https://wordpress.mcgruff.click`

## Example/estimated apply times (us-east-1)

| Config         | File             | Create | Destroy |
| -------------- | ---------------- | ------ | ------- |
| infrastructure | (all)            |  34:54 |   11:02 |
|                | vpc.tf           |   2:12 |    0:57 |
|                | cluster.tf       |  10:52 |   12:11 |
|                | directory.tf     |  28:54 |    8:14 |
|                | jump_host.tf     |   ?:?? |    ?:?? |
| application    | (all)            |   9:17 |    ?:?? |
|                | database.tf      |   4:56 |    4:50 |
|                | load_balancer.tf |   0:31 |    0:15 |
|                | deployment.tf    |   0:41 |    0:06 |
|                | ingress.tf       |   3:35 |    1:36 |

## Cleanup AWS Resources

Resources will need to be cleaned up in reverse order of their creation:

1. Destroy the Kubernetes application resources/deployment:

   ```
   cd terraform/application
   terraform destroy -var-file="global.tfvars"
   ```

   Wait for this to complete (approx. ??? minutes)

1. Destroy the AWS infrastructure resources:

   ```
   cd terraform/infrastructure
   terraform destroy -var-file="global.tfvars"
   ```

   Wait for this to complete (approx. ??? minutes)

## Notes

* **Component versions** - This project intentionally avoids specifying versions for any of its components (e.g. Terraform providers, cluster add-ons, AWS NLB, AMIs, etc.) - 'latest' versions are requested/assumed.  As a result, drift may occur over time and (hopefully minor) version-compatibility issues may arise in the project.

  **Note:** In production, you would definitely want to identify/specify component versions whenever possible for consistency/reproducibility reasons.

* **Resource version updates/upgrades** -   AWS makes availiable update/upgrade services for many/most components if provides (notable exception: the [AWS load-balancer controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/#create-update-strategy)) - you will likely want to investigate/implement these in a production environment.  (TODO: modify this project to implement those as a best practice).

* **Individual** `.tf` files can be moved into/out-of respective `disabled` folders to remove/create portioins of a config.

* **AWS CLI credentials timeout** - This can occur during Terraform `apply` and may result in interruption of the run (potentially causing corruption/sync problems between the actual resources and the Terraform state file.)

  It is possible to modify (i.e. increase) the AWS authentication session duration via: **IAM/Access management/Roles/{admin role}/Summary/Edit**.

  **Note:** Do this at your own risk and only in non-production environments - extended session lifetime can be a security risk.

  Once modified, you will want to modify your [AWS CLI authentication mechanism](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) to start requesting the longer session duration.

* **Corruption/sync issues in Terraform state files** - This can occur due to `apply` run interruptions (credential timeouit/network connection loss), or even just when provider-side errors/issues cause an abort.

  This can be difficult to recover from, but a few initial things to try, in increasing order of desperation:

  * Correct any problems in the configuration and re-`apply`.

  * Try `terraform plan -refresh=ADDRESS`, see [Command: plan](https://developer.hashicorp.com/terraform/cli/commands/plan#replace-address).

  * Destroy resources affected by the error using Terraform.  Try moving individual `.tf` files into `disabled/` or commenting-out specific resources.

  * Destroy the entire Terraform configuration and start fresh (`terraform destroy --var-file="../global.tfvars`).

  * If all else fails, you may need to manually delete some/all resources via the AWS admin console and delete the Terraform state files from the S3 bucket.

  * Start Googling, e.g. [How to Recover Your Deployment From a Terraform Apply Crash](https://eclipsys.ca/terraform-tips-how-to-recover-your-deployment-from-a-terraform-apply-crash/).

  

* **Update kubectl credentials** - Once the EKS cluster has been created, you can refresh kubectl credentials with:

  ```
  aws eks update-kubeconfig --region us-east-1 --name CLUSTERNAME
  ```

  **Note:** this is done automatically when the `terraform/infrastructure` configuration is applied.

* **View Kubernetes logs** - for the application deployment:

  ```
  kubectl -n namespace get pods
  kubectl -n namespace logs deployment-bbfd776f5-cs4fj
  ```

* **Restart deployment** - restart the application container, if necessary:

  ```
  kubectl -n namespace get pods
  kubectl rolling restart deployment deployment-bbfd776f5-cs4fj
  ```

* **Container interactive terminal session**:

  ```
  kubectl -n namespace get pods
  kubectl -n namespace exec -it deployment-bbfd776f5-cs4fj -- /bin/bash
  ```

* **Port forwarding from instance to local PC**:

  E.g. `3389` for RDP.

  ```
  aws ssm start-session --target yourinstanceid --document-name AWS-StartPortForwardingSession --parameters "localPortNumber=55678,portNumber=3389"
  ```

* **Check windows instance domain membership**:

  **Local PC:**
  ```
  aws ssm start-session --target yourInstanceId
  ```

  **Instance:**
  ```
  Get-WmiObject Win32_ComputerSystem
  ```
