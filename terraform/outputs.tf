output "conjur_auth_url" {
  description = "JWT authentication URL for workloads"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api/authn-jwt/${conjur_authenticator.jwt.name}/conjur/authenticate"
}

output "conjur_secret_base_url" {
  description = "Base URL for secret retrieval"
  value       = "https://${var.conjur_tenant}.secretsmgr.cyberark.cloud/api/secrets/conjur/variable/"
}

output "openweather_api_key_id" {
  description = "Conjur variable ID for the OpenWeather API key"
  value       = "${local.branch_openweather}/api-key"
}

output "openweather_api_key_id_encoded" {
  description = "URL-encoded variable ID (append to conjur_secret_base_url)"
  value       = replace("${local.branch_openweather}/api-key", "/", "%2F")
}

output "timezone_token_id" {
  description = "Conjur variable ID for the Timezone token"
  value       = "${local.branch_timezone}/token"
}

output "timezone_token_id_encoded" {
  description = "URL-encoded variable ID (append to conjur_secret_base_url)"
  value       = replace("${local.branch_timezone}/token", "/", "%2F")
}

output "workload_host_id" {
  description = "Full Conjur host ID for the workload identity"
  value       = "${local.branch_workloads}/${var.swa_nodegroup_name}"
}
