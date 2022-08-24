Free Tier AWS Dynamic DNS

This repo is a terraform configuration based upon the [AWS Labs dynamic dns lambda example](https://github.com/awslabs/route53-dynamic-dns-with-lambda). It does the following:

1. Creates a Route53 zone for the given root domain name, with SSL certs and validation DNS entries.
2. Configures namecheap with the domain name servers for that zone
3. Generates a shared secret password to authenticate update requests
4. Creates an S3 bucket to hold the domain configuration, and uploads the secrets config for the target host.
5. Uploads the domain update lamda function (`lamda.py`) and configures it with the bucket name and config file key.
6. Sets up API Gateway to route requests to the api endpoint to the lambda, configured against a subdomain on your target domain (default is `update`).
7. Creates said subdomain and points it at the api.

Once the configuration is applied, you will have a working dyndns service. Use the `update-dns.sh` script (after populating the outputs from terraform) to invoke the api endpoint.

### Usage:

Create a `secret.auto.tfvars` file in the root of this repository with the following values filled in:

```terraform
site = "NAME_FOR_SITE_IN_AWS"
domain = "your-domain.name"
api_subdomain = "update"

namecheap = {
  username = "NAMECHEAP_USERNAME"
  apikey = "NAMECHEAP_SECRET"
}
```