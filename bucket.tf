
resource "aws_s3_bucket" "config" {
  bucket = "${var.domain}.config"

  tags = {
    Name = "DynDNS Config"
    Site = var.site
  }
}

resource "aws_s3_bucket_acl" "config" {
  bucket = aws_s3_bucket.config.id
  acl    = "private"
}

resource "random_password" "secret" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

output shared_secret {
  description = "Shared Update Secret"
  value       = random_password.secret.result
  sensitive = true
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.config.bucket
  key    = "config.json"
  content = <<EOF
  {
    "${var.domain}.": {
      "aws_region": "${var.region}",
      "route_53_zone_id": "${aws_route53_zone.zone.zone_id}",
      "route_53_record_ttl": 60,
      "route_53_record_type": "A",
      "shared_secret": "${random_password.secret.result}"
    }
  }
  EOF

  depends_on = [
    aws_route53_zone.zone,
    random_password.secret
  ]
}
