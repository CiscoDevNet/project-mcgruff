data "aws_db_instance" "database" {
  db_instance_identifier = var.application_database_name
}

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
            value = data.aws_db_instance.database.address
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = data.aws_db_instance.database.master_username
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "Cisco!123"
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = data.aws_db_instance.database.db_name
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

resource "kubernetes_service" "wordpress_load_balancer" {

  metadata {
    name      = "wordpress-load-balancer"
    namespace = kubernetes_namespace.namespace.metadata.0.name

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"        = aws_acm_certificate.certificate.arn
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"       = "443"
    }
  }
  # wait_for_load_balancer = true
  spec {
    external_traffic_policy = "Local"
    selector = {
      app = "wordpress"
    }
    type = "LoadBalancer"

    port {
      port        = 443
      target_port = 80
      protocol    = "TCP"
    }
  }
  depends_on = [
    helm_release.aws_load_balancer,
    kubernetes_deployment.wordpress,
    kubernetes_service_account.aws_load_balancer
  ]
}

output "application_url" {
  value = kubernetes_service.wordpress_load_balancer.status[0].load_balancer[0].ingress[0].hostname
}
