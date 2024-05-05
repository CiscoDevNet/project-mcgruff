resource "kubernetes_persistent_volume_claim" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = "wordpress"
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

data "aws_secretsmanager_secret" "database" {
  arn = aws_db_instance.database.master_user_secret[0].secret_arn
}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = data.aws_secretsmanager_secret.database.id
}


resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = "wordpress"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = "wordpress"
          }
        }
        container {
          image = "wordpress:php8.3-apache"
          name  = "wordpress"
          port {
            container_port = 80
          }
          volume_mount {
            mount_path = "/var/www/html"
            name       = "wordpress-persistent-storage"
          }
          env {
            name  = "WORDPRESS_DB_HOST"
            value = aws_db_instance.database.address
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = aws_db_instance.database.username
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = jsondecode(data.aws_secretsmanager_secret_version.database.secret_string)["password"]
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = aws_db_instance.database.db_name
          }
          env {
            name  = "WORDPRESS_CONFIG_EXTRA"
            value = "define('WP_SITEURL', '//');define('WP_HOME', '//');"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_persistent_volume_claim.wordpress
  ]
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "self_signed_cert" {
  private_key_pem = tls_private_key.private_key.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "certificate" {
  private_key      = tls_private_key.private_key.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed_cert.cert_pem
}

resource "kubernetes_service_v1" "wordpress_service" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.namespace.metadata.0.name
    labels = {
      app = "wordpress"
    }
  }

  spec {
    type = "NodePort"
    selector = {
      app = "wordpress"
    }
    port {
      port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "wordpress_ingress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.namespace.metadata.0.name
    labels = {
      app = "wordpress"
    }
    annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name"   = "wordpress-ingress-load-balancer"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/certificate-arn"      = aws_acm_certificate.certificate.arn
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect" = "443"
    }
  }
  wait_for_load_balancer = true

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "wordpress"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }

  depends_on = [
    helm_release.aws_load_balancer,
    kubernetes_deployment.wordpress,
    kubernetes_service_account.aws_load_balancer,
    kubernetes_service_v1.wordpress_service
  ]
}

resource "null_resource" "local_exe1" {
  depends_on = [ kubernetes_ingress_v1.wordpress_ingress ]
  provisioner "local-exec" {
    command = "aws elbv2 wait load-balancer-available --names wordpress-ingress-load-balancer"
  }
}

output "application_url" {
  value = kubernetes_ingress_v1.wordpress_ingress.status[0].load_balancer[0].ingress[0].hostname
}
