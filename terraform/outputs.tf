output "conjur_auth_url" {
  description = "JWT authentication URL for workloads"
  value       = module.conjur_cloud.conjur_auth_url
}

output "conjur_secret_base_url" {
  description = "Base URL for secret retrieval"
  value       = module.conjur_cloud.conjur_secret_base_url
}

output "openweather_api_key_id" {
  description = "Conjur variable ID for the OpenWeather API key"
  value       = module.conjur_cloud.openweather_api_key_id
}

output "openweather_api_key_id_encoded" {
  description = "URL-encoded variable ID (append to conjur_secret_base_url)"
  value       = module.conjur_cloud.openweather_api_key_id_encoded
}

output "timezone_token_id" {
  description = "Conjur variable ID for the Timezone token"
  value       = module.conjur_cloud.timezone_token_id
}

output "timezone_token_id_encoded" {
  description = "URL-encoded variable ID (append to conjur_secret_base_url)"
  value       = module.conjur_cloud.timezone_token_id_encoded
}

output "workload_host_id" {
  description = "Full Conjur host ID for the workload identity"
  value       = module.conjur_cloud.workload_host_id
}
