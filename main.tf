
# Input Variables
# -----------------------------------------------------------------------------------------------------------

variable "region" {
  type = string
  description = "AWS Hosting Region"
  default = "us-east-1"
}

variable "site" {
  type = string
  description = "The name of the site"
  default = ""
}

variable "domain" {
  type = string
  description = "The base domain name of the site that all these belong to."
  default = ""
}

variable "api_subdomain" {
  type = string
  description = "The subdomain used for the update API"
  default = "update"
}

variable "namecheap" {
  type = map
  description = "Namecheap Credentials"
  default = {
    username = ""
    apikey = ""
  }

  validation {
    condition     = length(var.namecheap.username) > 0
    error_message = "Must provide a namecheap configuration."
  }
}

# variable "oauth_credentials" {
#   type = map
# }

# variable "dns_verification" {
#   type = map
# }


# Providers
# -----------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    namecheap = {
      source = "namecheap/namecheap"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
   region = var.region
}

data "http" "externalip" {
  url = "http://ipv4.icanhazip.com"
}

provider "namecheap" {
  user_name = var.namecheap.username
  api_user = var.namecheap.username
  api_key = var.namecheap.apikey
  client_ip = chomp(data.http.externalip.body)
  use_sandbox = false
}

