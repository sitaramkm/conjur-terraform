variable "conjur_tenant" {
  description = "Conjur Cloud tenant name (e.g. my-tenant)"
  type        = string
}

variable "conjur_resource_prefix" {
  description = "Prefix used for all Conjur resources created by this configuration"
  type        = string
}

variable "conjur_workload_host" {
  description = "Full Conjur host ID of the automation workload (e.g. data/my-workload). Granted read/update/execute on secrets in the managed branch."
  type        = string
}
