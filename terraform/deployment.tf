data "aws_eks_cluster_auth" "application_cluster_auth" {
  name = aws_eks_cluster.application_cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.application_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.application_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.application_cluster_auth.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.application_cluster.name]
      command     = "aws"
    }
}

resource "kubernetes_namespace" "application_namespace" {
  metadata {
    name = "application"
  }
}

resource "kubernetes_deployment" "application_deployment" {
  metadata {
    name      = "deployment"
    namespace = kubernetes_namespace.application_namespace.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "application_deployment"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "application_deployment"
        }
      }
      spec {
        container {
          image = "nginx"
          name  = "nginx"
          port {
            name = "web"
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "application_load_balancer" {
  metadata {
    name      = "loadbalancer"
    namespace = kubernetes_namespace.application_namespace.metadata.0.name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "application_deployment"
    }
    type = "LoadBalancer"
    port {
      protocol = "TCP"
      port        = 80
      target_port = "web"
    }
  }
}


