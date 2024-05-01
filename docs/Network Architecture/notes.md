## RunOn

* **Tenant**: DevNet_Sandbox
* **Service/AWS**: devnet-da-runon-aws

## AWS

* **SSO Login**: https://cloudsso.cisco.com/idp/startSSO.ping?PartnerSpId=https://signin.aws.amazon.com/saml

* Get kubectl config file for EKS cluster:

  ```
  aws eks update-kubeconfig --region us-east-1 --name cluster-default
  ```

* **Deployment logs**:

  ```
  kubectl -n application get pods
  kubectl -n application logs deployment-bbfd776f5-cs4fj
  ```
* **Restart deployment**:

  ```
  kubectl rolling restart deployment deployment-bbfd776f5-cs4fj
  ```

## Estimated apply times

| Config             | File          | Time  |
| ------------------ | ------------- | ----- |
| aws_infrastructure |               |       |
|                    | vpc.tf        |  0:26 |
|                    | cluster.tf    | 10:52 |
|                    | node.tf       |  1:53 |
|                    | database.tf   |  5:22 |
| k8s_application    |               |  0:22 |
|                    | deployment.tf |  0:22 |
