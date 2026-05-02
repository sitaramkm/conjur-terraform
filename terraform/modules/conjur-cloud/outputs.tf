output "authenticator_id" {
  description = "Full Conjur authenticator service ID (authn-jwt/<name>)"
  value       = "authn-jwt/${conjur_authenticator.jwt.name}"
}

output "conjur_auth_url" {
  description = "JWT authentication URL for workloads to obtain a Conjur token"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api/authn-jwt/${conjur_authenticator.jwt.name}/conjur/authenticate"
}

output "conjur_secret_base_url" {
  description = "Base URL for retrieving secrets from Conjur (append URL-encoded variable ID)"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api/secrets/conjur/variable/"
}

output "openweather_api_key_id" {
  description = "Full Conjur variable ID for the OpenWeather API key"
  value       = "${conjur_policy_branch.openweather.full_id}/api-key"
}

output "openweather_api_key_id_encoded" {
  description = "URL-encoded Conjur variable ID for the OpenWeather API key (for use in secret retrieval URLs)"
  value       = replace("${conjur_policy_branch.openweather.full_id}/api-key", "/", "%2F")
}

output "timezone_token_id" {
  description = "Full Conjur variable ID for the Timezone token"
  value       = "${conjur_policy_branch.timezone.full_id}/token"
}

output "timezone_token_id_encoded" {
  description = "URL-encoded Conjur variable ID for the Timezone token (for use in secret retrieval URLs)"
  value       = replace("${conjur_policy_branch.timezone.full_id}/token", "/", "%2F")
}

output "workload_host_id" {
  description = "Full Conjur host ID for the workload identity"
  value       = "${conjur_policy_branch.workloads.full_id}/${var.swa_nodegroup_name}"
}
