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

