resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks_cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = split(",", aws_cloudformation_stack.aws_cft_stack.outputs.SubnetIds)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_role_policy_attachment
  ]
}

resource "aws_iam_role" "eks_cluster_node_group_role" {
  name = "eks_cluster_node_group_role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "policy_attachment_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "policy_attachment_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "policy_attachment_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_cluster_node_group_role.name
}

resource "aws_eks_node_group" "eks_cluster_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks_cluster_node_group"
  node_role_arn   = aws_iam_role.eks_cluster_node_group_role.arn
  subnet_ids      = split(",", aws_cloudformation_stack.aws_cft_stack.outputs.SubnetIds)
  instance_types  = ["t3.small"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.policy_attachment_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.policy_attachment_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.policy_attachment_AmazonEC2ContainerRegistryReadOnly,
  ]
}
