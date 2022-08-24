
# Site DNS Zone and extra domains
# -----------------------------------------------------------------------------------------------------------

# aws_route53_zone.zone
resource "aws_route53_zone" "zone" {
  name = var.domain

  tags = {
    Site = var.site
    Category = "DNS"
  }
}

# namecheap_domain_records.zone
resource "namecheap_domain_records" "zone" {
  domain = var.domain
  mode = "OVERWRITE"

  nameservers = aws_route53_zone.zone.name_servers
}



# -----------------------------------------------------------------------------------------------------------
# A-Record

resource "aws_route53_record" "zone" {
  name    = var.domain
  zone_id = aws_route53_zone.zone.zone_id
  type    = "A"
  ttl     = "300"

  records = [
    chomp(data.http.externalip.body)
  ]
}

# resource "aws_route53_record" "google_verification" {
#   count = try(contains(keys(var.dns_verification), "google"), false) ? 1 : 0
#   zone_id = var.zone_id
#   name    = var.domain
#   type    = "TXT"
#   ttl     = 300

#   records = var.dns_verification.google
# }
