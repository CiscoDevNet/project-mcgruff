data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "certificate" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate_validation" "certificate" {
  timeouts {
    create = "5m"
  }
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
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
      "alb.ingress.kubernetes.io/load-balancer-name" = "wordpress-ingress-load-balancer"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/certificate-arn"    = aws_acm_certificate.certificate.arn
      "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"       = "443"
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

data "aws_lb" "wordpress" {
  name       = "wordpress-ingress-load-balancer"
  depends_on = [kubernetes_ingress_v1.wordpress_ingress]
}

resource "null_resource" "wait_for_load_balancer_active" {
  depends_on = [kubernetes_ingress_v1.wordpress_ingress]
  provisioner "local-exec" {
    command = "aws elbv2 wait load-balancer-available --names wordpress-ingress-load-balancer"
  }
}

resource "aws_route53_record" "wordpress" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "wordpress.${data.aws_route53_zone.zone.name}"
  type    = "A"
  alias {
    name                   = data.aws_lb.wordpress.dns_name
    zone_id                = data.aws_lb.wordpress.zone_id
    evaluate_target_health = false
  }
  depends_on = [null_resource.wait_for_load_balancer_active]
}

output "Application_URL" {
  value = "https://${aws_route53_record.wordpress.fqdn}"
}
