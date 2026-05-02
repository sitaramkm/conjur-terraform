#!/usr/bin/env bash
# conjur-tf.sh — orchestrator for the Conjur Cloud Terraform workflow
#
# Usage:
#   ./scripts/conjur-tf.sh init     # terraform init (first time or after provider changes)
#   ./scripts/conjur-tf.sh plan     # terraform plan
#   ./scripts/conjur-tf.sh create   # terraform apply
#   ./scripts/conjur-tf.sh destroy  # terraform destroy
#   ./scripts/conjur-tf.sh output   # terraform output -json
#
# Prerequisites:
#   - common.env present at repo root (copy from common.env.example)
#   - `conjur login` completed before plan / create / destroy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
COMMON_ENV="${ROOT_DIR}/common.env"

# ── Load common.env ───────────────────────────────────────────────────────────

[[ -f "${COMMON_ENV}" ]] || {
  echo "ERROR: ${COMMON_ENV} not found."
  echo "       Copy common.env.example to common.env and fill in CONJUR_TENANT."
  exit 1
}
# shellcheck disable=SC1090
source "${COMMON_ENV}"

: "${CONJUR_TENANT:?CONJUR_TENANT must be set in common.env}"

# ── Helpers ───────────────────────────────────────────────────────────────────

require_conjur_login() {
  echo "==> Checking Conjur CLI session..."
  if ! conjur whoami >/dev/null 2>&1; then
    echo "ERROR: Conjur CLI is not authenticated."
    echo "       Run 'conjur login' and retry."
    exit 1
  fi
  echo "    Session active."
}

run_terraform() {
  local subcmd="$1"; shift
  cd "${TF_DIR}"
  terraform "${subcmd}" "$@"
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_init() {
  echo "==> Running terraform init..."
  run_terraform init -upgrade
}

cmd_plan() {
  require_conjur_login
  echo "==> Running terraform plan..."
  run_terraform plan
}

cmd_create() {
  require_conjur_login
  echo "==> Running terraform apply..."
  run_terraform apply -auto-approve
}

cmd_destroy() {
  require_conjur_login
  echo "==> Running terraform destroy..."
  run_terraform destroy -auto-approve
}

cmd_output() {
  run_terraform output -json
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  init     Run terraform init (first time, or after upgrading the provider)
  plan     Run terraform plan  (requires conjur login)
  create   Run terraform apply (requires conjur login)
  destroy  Run terraform destroy (requires conjur login)
  output   Show terraform output as JSON

Environment (set in common.env):
  CONJUR_TENANT              Conjur Cloud tenant name
  CONJUR_APPLIANCE_URL       Conjur API URL (derived from CONJUR_TENANT)
  CONJUR_ACCOUNT             Conjur account (typically "conjur")
  TF_VAR_*                   Passed automatically to terraform
EOF
  exit 1
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

ACTION="${1:-}"
case "${ACTION}" in
  init)    cmd_init    ;;
  plan)    cmd_plan    ;;
  create)  cmd_create  ;;
  destroy) cmd_destroy ;;
  output)  cmd_output  ;;
  *)       usage       ;;
esac
