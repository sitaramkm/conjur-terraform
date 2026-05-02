variable "conjur_tenant" {
  description = "Conjur Cloud tenant name (e.g. mycompany — the subdomain before .secretsmgr.cyberark.cloud)"
  type        = string
}

variable "swa_resource_prefix" {
  description = "Resource prefix used to namespace all Conjur policy branches (matches SWA_RESOURCE_PREFIX)"
  type        = string
}

variable "swa_oidc_issuer_url" {
  description = "OIDC issuer URL emitted by SWA; used as JWT issuer and JWKS base URL"
  type        = string
}

variable "swa_nodegroup_name" {
  description = "Name of the SWA node group — becomes the Conjur host identity leaf name"
  type        = string
}

variable "spiffe_subject" {
  description = "SPIFFE subject (sub claim) placed in the JWT; used to annotate the Conjur host for authn-jwt binding"
  type        = string
}

variable "conjur_jwt_audience" {
  description = "JWT audience expected by the Conjur authenticator"
  type        = string
  default     = "conjur"
}

variable "openweather_api_key" {
  description = "Sample OpenWeather API key value written as a Conjur secret (write-only; not stored in state)"
  type        = string
  sensitive   = true
}

variable "timezone_token" {
  description = "Sample Timezone API token value written as a Conjur secret (write-only; not stored in state)"
  type        = string
  sensitive   = true
}
