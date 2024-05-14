module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.10.0"

  cluster_name                             = var.cluster_name
  cluster_version                          = "1.29"
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  create_cloudwatch_log_group              = false

  cluster_tags = {
    Name = var.cluster_name
  }

  cluster_addons = {
    vpc-cni = {
      version = "1.16.0-eksbuild.1"
    }
    coredns = {
      version = "1.11.1-eksbuild.4"
    }
    kube-proxy = {
      version = "v1.29.0-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      version = "v1.30.0-eksbuild.1"
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  eks_managed_node_groups = {
    node_group = {
      name           = var.node_group_name
      subnet_ids     = module.vpc.private_subnets
      instance_types = ["t2.small"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 10

      min_size     = 1
      max_size     = 2
      desired_size = 1
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false
    }
  }
}

resource "null_resource" "update_kubectl_config" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name}"
  }
}
