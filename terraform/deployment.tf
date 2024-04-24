data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = aws_eks_cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
  #   exec {
  #     api_version = "client.authentication.k8s.io/v1beta1"
  #     args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  #     command     = "aws"
  #   }
}

resource "kubernetes_namespace" "application" {
  metadata {
    name = "application"
  }
}

resource "kubernetes_deployment" "application" {
  metadata {
    name      = "application"
    namespace = kubernetes_namespace.application.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "application"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "application"
        }
      }
      spec {
        container {
          image = "nginx"
          name  = "application"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "application" {
  metadata {
    name      = "application"
    namespace = kubernetes_namespace.application.metadata.0.name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "application"
    }
    type = "ClusterIP"
    port {
      protocol = "TCP"
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "application" {
  metadata {
    name = "application"
    namespace = "application"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }
#   wait_for_load_balancer = true

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "application"
              port {
                number = 80
              }
            }
          }

        }
      }
    }
  }
}
