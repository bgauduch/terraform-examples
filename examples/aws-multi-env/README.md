# Terraform Multi-Environment Demo (AWS)

[![Terraform quality](https://github.com/bgauduch/demo-terraform-multi-env-aws/actions/workflows/terraform.yml/badge.svg?branch=main)](https://github.com/bgauduch/demo-terraform-multi-env-aws/actions/workflows/terraform.yml)
[![Release](https://github.com/bgauduch/demo-terraform-multi-env-aws/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/bgauduch/demo-terraform-multi-env-aws/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/bgauduch/demo-terraform-multi-env-aws?sort=semver&display_name=tag)](https://github.com/bgauduch/demo-terraform-multi-env-aws/releases/latest)

Progressive demonstration of multi-environment management with Terraform CE (Community Edition) on AWS.

Supporting content for the "Matinale Tech" Twitch live stream.

> **⚠️ Demo only - not for production use**
>
> This repository is intended as a pedagogical demo to illustrate multi-environment patterns. Configuration is deliberately kept minimal to keep the focus on multi-env structure.
>
> For production use, you should at minimum:
> - use a **remote backend** (S3, or HCP Terraform) with locking instead of the local state used here
> - pin provider and module versions strictly, and manage credentials via a proper secrets mechanism
> - wrap everything in a CI/CD pipeline with policy-as-code, plan reviews, and drift detection

> **Note**: these demos and approaches concern Terraform CE. In CE mode, you have to build and maintain all the CI/CD "glue" yourself (S3 backend, DynamoDB locking, pipelines, credentials management, policy as code, etc.). For an out-of-the-box experience, head to [HCP Terraform](https://www.hashicorp.com/products/terraform/pricing/) - the cost of licenses largely covers the build and run costs of a custom CI/CD stack around TF CE.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with valid credentials
- Default region: `eu-west-1` (Paris)

## Deployed resources

Simple network topology (free, quick to create/destroy):

- **VPC** with a CIDR variable per environment
- **2 subnets**: public + private (computed via `cidrsubnet()`)
- **Tags**: Project, Environment, ManagedBy

## Structure

Each level is self-contained and can be run independently.

```
level-0-single-env/         # One root module, a single environment
level-1-workspaces/         # One root module, Terraform workspaces
level-2-root-per-env/       # One root module per env + shared modules
level-3-specialization/     # One root module + specialization via -backend-config and -var-file
```

## Level 0 - Single Environment

"Monolithic" approach: one root module, one state, one environment.

```bash
cd level-0-single-env
terraform init
terraform plan
terraform apply
terraform destroy
```

- (+) simple, quick to set up
- (-) impossible to manage multiple environments without duplicating code

## Level 1 - Workspaces

A single root module using `terraform.workspace` to differentiate environments. The state is automatically separated per workspace.

```bash
cd level-1-workspaces
terraform init

terraform workspace new dev
terraform plan
terraform apply

terraform workspace new prod
terraform plan
terraform apply

# Cleanup
terraform workspace select dev && terraform destroy
terraform workspace select prod && terraform destroy
```

- (+) state automatically separated per workspace, zero code duplication
- (-) env config hardcoded in locals, risk of applying on the wrong workspace, no real isolation
- Approach discouraged by the [official docs](https://developer.hashicorp.com/terraform/cli/workspaces#when-not-to-use-multiple-workspaces) for multi-env management

## Level 2 - Root Module per Environment

Structure recommended by the [official Terraform docs](https://developer.hashicorp.com/terraform/language/style) for users outside HCP Terraform/TFE.

One directory per env, each with its own state. Modules are shared.

```bash
# Dev
cd level-2-root-per-env/dev
terraform init
terraform plan
terraform apply

# Prod
cd ../prod
terraform init
terraform plan
terraform apply

# Cleanup
cd ../dev && terraform destroy
cd ../prod && terraform destroy
```

- (+) full state isolation, no risk of env mistake, reusable modules
- (-) duplication of root code (providers, outputs) between envs

## Level 3 - Root Module + Specialization

A single root module. The target environment is selected at execution time via:

- `terraform init -backend-config=env/<env>.backend.hcl` for the state
- `terraform plan/apply -var-file=env/<env>.tfvars` for the configuration

```bash
cd level-3-specialization

# Dev
terraform init -backend-config=env/dev.backend.hcl
terraform plan -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars

# Prod (re-init required to change backend)
terraform init -reconfigure -backend-config=env/prod.backend.hcl
terraform plan -var-file=env/prod.tfvars
terraform apply -var-file=env/prod.tfvars

# Cleanup
terraform init -reconfigure -backend-config=env/dev.backend.hcl
terraform destroy -var-file=env/dev.tfvars
terraform init -reconfigure -backend-config=env/prod.backend.hcl
terraform destroy -var-file=env/prod.tfvars
```

- (+) zero code duplication, adding an env = 2 files (`.tfvars` + `.backend.hcl`)
- (-) requires an `init -reconfigure` to switch envs locally (transparent in CI/CD)

## Going further

- **Terragrunt**: wrapper around Terraform that pushes DRY even further (backend management, inputs, dependencies between modules). Caveat: wrapper-only mode, no easy way back once adopted - a structuring choice for the team.
- **Terraform Stacks**: recent HCP Terraform feature to orchestrate multiple root modules as a unit (deployments, deferred changes).

## Technical points demonstrated

- `cidrsubnet()` for dynamic CIDR computation
- `aws_availability_zones` data source for dynamic AZ selection
- `merge()` for tag composition
- `lookup()` with fallback (level 1)
- Backend / env variables separation (level 3)
- Provider-defined functions (v1.8+): `provider::aws::arn_parse()`, `provider::aws::arn_build()`
