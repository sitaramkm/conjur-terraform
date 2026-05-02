variable "conjur_tenant" {
  description = "Conjur Cloud tenant name (e.g. my-tenant)"
  type        = string
}

variable "conjur_resource_prefix" {
  description = "Prefix used for all Conjur resources created by this configuration"
  type        = string
}

variable "openweather_api_key" {
  description = "API key for the OpenWeather service"
  type        = string
  sensitive   = true
}

variable "timezone_token" {
  description = "Token for the Timezone service"
  type        = string
  sensitive   = true
}
