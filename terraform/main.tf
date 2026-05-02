terraform {
  required_version = ">= 1.11"

  required_providers {
    conjur = {
      source  = "cyberark/conjur"
      version = "~> 0.8"
    }
  }
}

# Provider credentials are read from environment variables:
#
#   CONJUR_APPLIANCE_URL  — https://<tenant>.secretsmgr.cyberark.cloud/api
#   CONJUR_ACCOUNT        — conjur
#   CONJUR_AUTHN_LOGIN    — admin (or your service-account login)
#   CONJUR_AUTHN_API_KEY  — your API key / password
#
# scripts/run.sh sets CONJUR_APPLIANCE_URL from CONJUR_TENANT automatically.
provider "conjur" {}

module "conjur_cloud" {
  source = "./modules/conjur-cloud"

  conjur_tenant       = var.conjur_tenant
  swa_resource_prefix = var.swa_resource_prefix
  swa_oidc_issuer_url = var.swa_oidc_issuer_url
  swa_nodegroup_name  = var.swa_nodegroup_name
  spiffe_subject      = var.spiffe_subject
  conjur_jwt_audience = var.conjur_jwt_audience
  openweather_api_key = var.openweather_api_key
  timezone_token      = var.timezone_token
}
