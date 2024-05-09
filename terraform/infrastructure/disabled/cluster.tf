module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name = var.cluster_name

  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  create_cloudwatch_log_group              = false

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    cluster_tags = {
      Name = var.cluster_name
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
      capacity_type  = "SPOT"
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