variable "conjur_tenant" {
  description = "Conjur Cloud tenant name (e.g. my-tenant)"
  type        = string
}

variable "conjur_login" {
  description = "Conjur login for the automation workload host. Get with: conjur whoami"
  type        = string
}

variable "conjur_api_key" {
  description = "Conjur API key for conjur_login. Get with: conjur host rotate-api-key -i <host-id>"
  type        = string
  sensitive   = true
}

variable "conjur_resource_prefix" {
  description = "Prefix used for all Conjur resources (must match the admin workspace)"
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
