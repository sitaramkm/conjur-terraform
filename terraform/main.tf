# Minimal slice: verify that conjur_policy_branch creation and conjur_secret
# value-push both work against Conjur Cloud before expanding to the full
# authenticator + workload-identity structure.

# ── Policy branch: data/<prefix> ─────────────────────────────────────────────

resource "conjur_policy_branch" "app_root" {
  branch = "data"
  name   = var.conjur_resource_prefix
}

# ── Secrets ───────────────────────────────────────────────────────────────────
# value_wo keeps the secret out of Terraform state (requires Terraform >= 1.11).
# Branch is expressed as a literal interpolation rather than full_id so the
# value is known at plan time (ValidateBranch rejects unknown/computed values).
# depends_on ensures the branch exists before the secret is created.
# To rotate a secret value: change value_wo and add/increment value_wo_version.

resource "conjur_secret" "openweather_api_key" {
  branch   = "data/${var.conjur_resource_prefix}"
  name     = "openweather-api-key"
  value_wo = var.openweather_api_key

  depends_on = [conjur_policy_branch.app_root]
}

resource "conjur_secret" "timezone_token" {
  branch   = "data/${var.conjur_resource_prefix}"
  name     = "timezone-token"
  value_wo = var.timezone_token

  depends_on = [conjur_policy_branch.app_root]
}
