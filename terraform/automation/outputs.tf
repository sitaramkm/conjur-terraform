output "conjur_tenant" {
  description = "Conjur Cloud tenant"
  value       = var.conjur_tenant
}

output "conjur_resource_prefix" {
  description = "Resource prefix used for all created Conjur resources"
  value       = var.conjur_resource_prefix
}

output "conjur_appliance_url" {
  description = "Conjur API appliance URL"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api"
}

output "conjur_secret_url_base" {
  description = "Base URL for fetching Conjur secrets via the REST API"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api/secrets/conjur/variable/"
}

output "openweather_api_key_id" {
  description = "Full Conjur variable ID for the OpenWeather API key (URL-encoded for REST API use)"
  value       = replace("data/${var.conjur_resource_prefix}/${conjur_secret.openweather_api_key.name}", "/", "%2F")
}

output "timezone_token_id" {
  description = "Full Conjur variable ID for the Timezone token (URL-encoded for REST API use)"
  value       = replace("data/${var.conjur_resource_prefix}/${conjur_secret.timezone_token.name}", "/", "%2F")
}
