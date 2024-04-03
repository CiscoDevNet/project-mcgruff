# Network Architecture for Project McGruff

## Overview

Reference cloud application deployment incorporating various Cisco security technology APIs.  Focus on common real-world components and patterns, applying security best practices.

## Application

A 'typical' containerized, client-server, web application with internal REST API and access group use-cases for at least 3 classes of users (admin/employee/external-customer).

### Components

#### Application Platform

* [AWS EKS](https://aws.amazon.com/eks/) (Kubernetes) - single pod/node/cluster.

* LAMP or similar, proposing [OpenCart](https://www.opencart.com/) in a [Binami container](https://bitnami.com/stack/opencart) for initial MVP.

* [AWS Relational Database Services (RDS)](https://aws.amazon.com/rds/) hosting MySQL.

#### Network Infrastructure

* [AWS Directory](https://aws.amazon.com/directoryservice/) providing MS Activer Directory.

* AWS Virtual Private Cloud (hosting EKS cluster) for egress/ingress and standard network services (DNS)

#### Infrastructure-as-Code Automation

* [Terraform Cloud](https://app.terraform.io) (free tier - 500 resources)

* [GitHub](https://github.com/) version control.

#### Security Products

* [DUO SSO/MFA](https://duo.com/)

* (Others TBD)