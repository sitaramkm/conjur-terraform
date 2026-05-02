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

### 1. Configure common.env

```bash
cp common.env.example common.env
# Edit common.env — set your tenant, credentials, and TF_VAR_* values
```

`common.env` is gitignored. It holds your Conjur credentials and all
Terraform variable values. `scripts/run.sh` sources it automatically.

### 2. Log in to Conjur CLI

```bash
conjur login -u admin -p <api-key>
conjur whoami   # verify session
```

`run.sh` checks `conjur whoami` as a preflight before every Terraform run.

## Usage

```bash
./scripts/run.sh create    # bootstrap all Conjur resources and push secrets
./scripts/run.sh destroy   # tear down all Conjur resources
./scripts/run.sh output    # print Terraform outputs
```

Or run Terraform directly after sourcing `common.env` (always use `-parallelism=1`):

```bash
source common.env
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply -parallelism=1 tfplan
```

> **Why `-parallelism=1`?**  Conjur rejects concurrent policy loads under
> the same branch with `409 Conflict`.  Running with parallelism=1 ensures
> resources are created one at a time.

## Rotating a secret value

Update the value in `common.env` and re-apply:

```bash
# common.env
export TF_VAR_openweather_api_key="NEW-API-KEY"
```

```bash
./scripts/run.sh create
```

Because `value_wo` is write-only, the value is never stored in Terraform
state — only pushed to Conjur.

## Repository structure

```
conjur-terraform/
├── common.env.example              # Copy to common.env (gitignored)
├── scripts/
│   └── run.sh                      # Preflight + Terraform wrapper
└── terraform/
    ├── main.tf                     # Provider config + module call
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example    # Alternative to common.env for direct tf use
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
