# conjur-terraform

Terraform demo that replicates the full `api/run.sh` workflow using
first-class resources from the
[cyberark/conjur](https://registry.terraform.io/providers/cyberark/conjur/latest)
Terraform provider

This demonstrates the **Push Secrets** pattern: Terraform creates the Conjur
policy structure *and* writes secret values in a single `apply`, without any
CLI scripting.

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
Terraform variable values. 

### 2. Log in to Conjur CLI

```bash
conjur login -u admin -p <api-key>
conjur whoami   # verify session
```

`run.sh` checks `conjur whoami` as a preflight

## Usage

```bash
./api/run.sh create    # bootstrap all Conjur resources and push secrets
./api/run.sh destroy   # tear down all Conjur resources
./api/run.sh usage    # prints usage
```

