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
# Increment value_wo_version to rotate the secret value on subsequent applies.

resource "conjur_secret" "openweather_api_key" {
  branch          = conjur_policy_branch.app_root.full_id
  name            = "openweather-api-key"
  value_wo        = var.openweather_api_key
  value_wo_version = 1
}

resource "conjur_secret" "timezone_token" {
  branch          = conjur_policy_branch.app_root.full_id
  name            = "timezone-token"
  value_wo        = var.timezone_token
  value_wo_version = 1
}
