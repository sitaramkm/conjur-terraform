variable "conjur_tenant" {
  description = "Conjur Cloud tenant name (subdomain before .secretsmgr.cyberark.cloud)"
  type        = string
}

variable "swa_resource_prefix" {
  description = "Resource prefix used to namespace all Conjur policy branches (SWA_RESOURCE_PREFIX)"
  type        = string
  default     = "swa-demo"
}

variable "swa_oidc_issuer_url" {
  description = "OIDC issuer URL from SWA; becomes the JWT issuer and JWKS base URL"
  type        = string
}

variable "swa_nodegroup_name" {
  description = "SWA node group name; used as the Conjur host identity leaf name (SWA_NODEGROUP_NAME)"
  type        = string
}

variable "spiffe_subject" {
  description = "SPIFFE subject (JWT sub claim) placed in the Conjur host annotation for authn-jwt binding"
  type        = string
}

variable "conjur_jwt_audience" {
  description = "JWT audience expected by the Conjur authenticator"
  type        = string
  default     = "conjur"
}

variable "openweather_api_key" {
  description = "OpenWeather API key to push into Conjur (write-only; not stored in state)"
  type        = string
  sensitive   = true
  default     = "FAKE-OPENWEATHER-API-KEY"
}

variable "timezone_token" {
  description = "Timezone API token to push into Conjur (write-only; not stored in state)"
  type        = string
  sensitive   = true
  default     = "FAKE-TIMEZONE-TOKEN"
}
