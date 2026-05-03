output "policy_branch_path" {
  description = "Full Conjur policy path of the managed branch (e.g. data/my-prefix)"
  value       = local.full_id
}

output "conjur_tenant" {
  description = "Conjur Cloud tenant"
  value       = var.conjur_tenant
}

output "conjur_resource_prefix" {
  description = "Resource prefix used for all created Conjur resources"
  value       = var.conjur_resource_prefix
}
