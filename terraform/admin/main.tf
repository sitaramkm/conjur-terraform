# Admin workspace — manages Conjur policy structure using the active CLI session.
#
# This workspace uses `conjur policy load` (via local-exec) rather than the
# Conjur Terraform provider, so it works with whatever `conjur login` session
# is currently active — no API key is required here.
#
# Responsibilities:
#   • Create the policy branch that scopes all automation secrets
#   • Grant the automation workload host read/update/execute on secrets in that branch
#   • Remove the branch (and all resources under it) on teardown
#
# Run order:
#   1. admin-setup  → creates branch + grants
#   2. create       → automation workspace pushes secret values
#   3. admin-teardown → removes branch + all secrets (irreversible)

locals {
  parent_branch = "data"
  branch_name   = var.conjur_resource_prefix
  full_id       = "${local.parent_branch}/${local.branch_name}"
}

resource "null_resource" "policy_branch" {
  triggers = {
    parent_branch = local.parent_branch
    branch_name   = local.branch_name
    workload_host = var.conjur_workload_host
  }

  provisioner "local-exec" {
    environment = {
      PARENT_BRANCH = self.triggers.parent_branch
      BRANCH_NAME   = self.triggers.branch_name
      WORKLOAD_HOST = self.triggers.workload_host
    }
    command = <<-SHELL
      # Strip the "host/" kind prefix if the caller accidentally included it
      host_id="$${WORKLOAD_HOST#host/}"
      tmpfile=$(mktemp /tmp/conjur-branch-XXXXX.yml)
      trap 'rm -f "$tmpfile"' EXIT

      # Declare the branch, the variables it will hold, and the workload host's
      # permissions in a single policy load.  The automation workspace (conjur_secret)
      # cannot load policy itself, so all structural declarations must be made here.
      #
      # To add a new secret: add a !variable + !permit pair below, re-run admin-setup,
      # then add the corresponding conjur_secret resource in terraform/automation/main.tf.
      cat > "$tmpfile" <<POLICY
- !policy
  id: $BRANCH_NAME
  body:
    - !variable openweather-api-key
    - !variable timezone-token

    - !permit
      role: !host /$host_id
      privileges: [read, update, execute]
      resource: !variable openweather-api-key

    - !permit
      role: !host /$host_id
      privileges: [read, update, execute]
      resource: !variable timezone-token
POLICY
      echo "==> Loading policy branch: $PARENT_BRANCH/$BRANCH_NAME"
      conjur policy load -b "$PARENT_BRANCH" -f "$tmpfile"
    SHELL
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      PARENT_BRANCH = self.triggers.parent_branch
      BRANCH_NAME   = self.triggers.branch_name
    }
    command = <<-SHELL
      tmpfile=$(mktemp /tmp/conjur-delete-XXXXX.yml)
      trap 'rm -f "$tmpfile"' EXIT
      cat > "$tmpfile" <<POLICY
- !delete
  record: !policy $BRANCH_NAME
POLICY
      echo "==> Deleting policy branch: $PARENT_BRANCH/$BRANCH_NAME"
      conjur policy load -b "$PARENT_BRANCH" -f "$tmpfile"
    SHELL
  }
}