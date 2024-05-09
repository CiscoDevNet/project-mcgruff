# CiscoDevNet/project-mcgruff

## Overview

Reference cloud application deployment incorporating various Cisco security technology APIs.  Focuses on common real-world components and patterns, applying security best practices.

![Network architecture](images/network_architecture.png)

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

* **Amazon AWS admin account** - this must be a paid account.  Note: this project creates AWS resources that will incur (modest) ongoing charges - be sure to perform the steps in [Cleanup AWS Resources](#cleanup-aws-resources) as needed.

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installation - assumes login credentials have been obtained and CLI commands can be executed against the target AWS account/region.

* [AWS Route 53](https://aws.amazon.com/route53/) registered domain, owned by the AWS admin account above.  This domain will be used for the web-site/MS-AD - required for integration with Cisco Duo SSO/MFA.

* [Kubectl](https://kubernetes.io/docs/tasks/tools/) installation.

* [Helm](https://helm.sh/docs/intro/install/) installation.

## Getting Started

1. Clone the repository and change into the directory:

   ```
   git clone https://github.com/CiscoDevNet/project-mcgruff
   cd project-mcgruff
   ```

1. Edit `/terraform/global.tfvars` as needed.

   All values can be left commented/default except `domain_name`, which must be provided.

1. First, create the infrastructure resources:

   ```
   cd terraform/aws_infrastructure
   terraform apply -var-file="../global.tfvars"
   ```

   Allow this to complete (approx. 30 minutes).

1. Next, create resources and deploy the application:

   ```
   cd terraform/k8s_application
   terraform apply -var-file="../global.tfvars"
   ```

   Allow this to complete (approx. 10 minutes).

1. Output from the application deployment will indicate the application URL, based on the provided domain name, e.g.: `https://wordpress.mcgruff.click`

<!-- 1. TBD accessing MS AD administration -->

## Cleanup AWS Resources

Resources will need to be cleaned up in reverse order of their creation:

1. Destroy the Kubernetes application resources/deployment:

   ```
   cd terraform/k8s_application
   terraform destroy -var-file="global.tfvars"
   ```

   Wait for this to complete (approx. ??? minutes)

1. Destroy the AWS infrastructure resources:

   ```
   cd terraform/aws_infrastructure
   terraform destroy -var-file="global.tfvars"
   ```

   Wait for this to complete (approx. ??? minutes)

## Notes

* **Update kubectl credentials** - Once the EKS cluster has been created, you can refresh kubectl credentials with:

  ```
  aws eks update-kubeconfig --region us-east-1 --name CLUSTERNAME
  ```

  **Note:** this is done automatically when the `terraform/aws_infrastructure` configuration is applied.

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

## Example/estimated apply times (us-east-1)

| Config             | File             | Create | Destroy |
| ------------------ | ---------------- | ------ | ------- |
| aws_infrastructure | (all)            |  34:54 |   11:02 |
|                    | vpc.tf           |   0:26 |    0:57 |
|                    | cluster.tf       |  10:52 |   12:11 |
|                    | directory.tf     |  28:54 |    8:14 |
| k8s_application    | (all)            |   9:17 |         |
|                    | database.tf      |   4:56 |    4:50 |
|                    | load_balancer.tf |   0:31 |    0:15 |
|                    | deployment.tf    |   0:41 |    0:06 |
|                    | ingress.tf       |   3:35 |    1:36 |