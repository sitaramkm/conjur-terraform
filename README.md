# conjur-terraform

Terraform demo that replicates the full `conjur/config.sh` workflow using
first-class resources from the
[cyberark/conjur](https://registry.terraform.io/providers/cyberark/conjur/latest)
Terraform provider (≥ 0.8.0, released November 2025).

This demonstrates the **Push Secrets** pattern: Terraform creates the Conjur
policy structure *and* writes secret values in a single `apply`, without any
CLI scripting.

## What gets created

| Step | Resource | Conjur equivalent |
|------|----------|-------------------|
| 1 | `conjur_authenticator` | JWT authenticator + all `conjur variable set` config calls + `authenticator enable` |
| 2 | `conjur_policy_branch` (×5) | Policy tree under `data/` |
| 3 | `conjur_group` | `!group apps` in workload policy |
| 4 | `conjur_host` | `!host` with `authn-jwt/<id>/sub` annotation |
| 5 | `conjur_membership` (×2) | `!grant` + authn-jwt-grant |
| 6 | `conjur_secret` (×2) | `!variable` + `!permit` + `conjur variable set` |

The resulting Conjur variable paths mirror `config.sh` exactly:

```
data/<prefix>/secrets/saas-external-apis/openweather/api-key
data/<prefix>/secrets/saas-external-apis/timezone/token
```

## Requirements

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.11 (required for write-only `value_wo` on secrets) |
| Conjur CLI | any recent version |
| Conjur Cloud tenant | access with admin credentials |

## Setup

### 1. Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your tenant, prefix, OIDC issuer, etc.
```

### 2. Export provider credentials

The provider reads these environment variables directly:

```bash
export CONJUR_TENANT="mycompany"
export CONJUR_AUTHN_LOGIN="admin"
export CONJUR_AUTHN_API_KEY="<your-api-key>"   # the password you use with conjur login
```

> **Note:** `CONJUR_APPLIANCE_URL` and `CONJUR_ACCOUNT` are derived automatically
> by `scripts/run.sh`.  If you run Terraform directly, set them yourself:
> ```bash
> export CONJUR_APPLIANCE_URL="https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api"
> export CONJUR_ACCOUNT="conjur"
> ```

### 3. Log in to Conjur CLI (preflight check)

```bash
conjur login -u admin -p <api-key>
conjur whoami   # verify session
```

## Usage

```bash
# Bootstrap everything
./scripts/run.sh create

# Tear down
./scripts/run.sh destroy

# Show outputs only
./scripts/run.sh output
```

Or run Terraform directly (always use `-parallelism=1`):

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply -parallelism=1 tfplan
```

> **Why `-parallelism=1`?**  Conjur rejects concurrent policy loads under
> the same branch with `409 Conflict`.  Running with parallelism=1 ensures
> resources are created one at a time.

## Rotating a secret value

Increment `value_wo_version` in `terraform.tfvars` and re-apply:

```hcl
# terraform.tfvars
openweather_api_key = "NEW-API-KEY"
# also bump the version in modules/conjur-cloud/main.tf or override via TF_VAR:
```

```bash
TF_VAR_openweather_api_key="NEW-KEY" terraform apply -parallelism=1
```

Because `value_wo` is write-only, the value is never stored in Terraform
state — only pushed to Conjur.

## Repository structure

```
conjur-terraform/
├── scripts/
│   └── run.sh                      # Preflight + Terraform wrapper
└── terraform/
    ├── main.tf                     # Provider config + module call
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── modules/
        └── conjur-cloud/
            ├── main.tf             # All Conjur resources
            ├── variables.tf
            └── outputs.tf
```

## Differences from config.sh

| config.sh | This repo |
|-----------|-----------|
| `!variable id: openweather/api-key` (slash in variable name) | Separate `openweather` branch + `api-key` variable — same full path, more explicit Terraform structure |
| `data` root assumed pre-existing | `data/${prefix}` created explicitly; `data` itself must pre-exist (standard in Conjur Cloud) |
| Permissions via `!permit` in policy YAML | `permissions` block on `conjur_secret` resource |
