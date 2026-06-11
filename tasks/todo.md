# Restructure: single demo -> Terraform examples library

Repo: `demo-terraform-multi-env-aws` -> `terraform-examples`
Layout: flat `examples/<name>/`, per-example tooling + README + AGENTS.
Taxonomy: `type` (pattern | lab | experiment) + free tags, source of truth = root README catalogue table.

## Decisions (locked)
- CI: auto-discovery of TF root dirs (replaces `.github/levels.json`)
- Release: repo-level single package (release-please unchanged, rename package only)
- Repo name: `terraform-examples`
- Current demo folder: `examples/aws-multi-env/` (type: pattern)
- Docs language: English
- GitHub rename: autonomous (`gh repo rename` + remote update), but MILESTONE CHECKPOINT before any push/rename

## Tasks

### 1. Move current demo into examples/aws-multi-env/
- [ ] mkdir -p examples/aws-multi-env
- [ ] git mv level-0..3 dirs -> examples/aws-multi-env/
- [ ] git mv .terraform-version .tflint.hcl -> examples/aws-multi-env/
- [ ] git mv README.md -> examples/aws-multi-env/README.md

### 2. Docs split
- [ ] examples/aws-multi-env/AGENTS.md = current AWS-multi-env specifics (extracted from root AGENTS.md)
- [ ] root AGENTS.md rewritten: library conventions + "how to add an example" golden path + taxonomy
- [ ] CLAUDE.md symlink at root unchanged (-> AGENTS.md)
- [ ] root README.md new: pitch + catalogue table + add-an-example + badges (URLs -> terraform-examples)

### 3. CI generalization (.github/)
- [ ] terraform.yml: replace levels.json load with discover step (find examples -name providers.tf -> matrix)
- [ ] tf-setup/action.yml: add `working-directory` input to read example's .terraform-version; support prerelease/RC
- [ ] fmt job: keep `-recursive` at root
- [ ] delete .github/levels.json

### 4. Release config
- [ ] release-please-config.json: package-name -> terraform-examples (stay single-package ".")

### 5. Scaffold examples/terraform-rc-variables/ (type: experiment)
- [ ] README.md: deferred actions (`plan -allow-deferral`) scenario = dynamic KMS key ARN unknown at plan
- [ ] .terraform-version (RC pin, verify exact version vs docs)
- [ ] .tflint.hcl
- [ ] main.tf stub (calling module + KMS ARN var) so auto-discovery validates it
- [ ] register row in root README catalogue

### 6. Validate (local, before checkpoint)
- [ ] terraform fmt -check -recursive
- [ ] terraform validate in each moved root dir
- [ ] dry-run discover step lists aws-multi-env cells + rc stub

### 7. MILESTONE CHECKPOINT -> wait for user OK, then:
- [ ] commit (refactor! — breaking: paths/URLs change)
- [ ] gh repo rename terraform-examples + update local remote
- [ ] push

## Review (done)

- Branch `refactor/terraform-examples-library` -> PR #10 (base `main`).
- Repo renamed `demo-terraform-multi-env-aws` -> `terraform-examples` (remote updated, GitHub redirect kept).
- Commits: `chore(entire): disable telemetry`, `refactor!: restructure into a Terraform examples library` (+ inherited `chore(gitignore): track entire tool config`).
- Layout: `examples/aws-multi-env/` (pattern) + `examples/terraform-rc-variables/` (experiment, deferred-actions / KMS ARN unknown at plan).
- CI generalized: auto-discovery via `providers.tf`, per-example `.terraform-version` (walk-up) + `.tflint.hcl` (`--config`); `levels.json` removed.
- **CI green**: 9/9 checks pass (fmt, discover, 6 validate+lint+scan cells, conventional commits). Local: fmt + validate + tflint all green on 6 modules.

### Follow-ups (not in this PR)
- Decide later if `aws-multi-env` levels warrant per-level subdivision in the catalogue.

---

# Plan: implement terraform-deferred-actions example

Toolchain: `1.16.0-alpha20260603` (deferred/unknown-instances + ephemeral_values are CONCLUDED -> native, NO `experiments` block, NO `-allow-deferral` flag).

## Goal
Root module creates a KMS key and instantiates a generic S3 child module **twice** to prove both encryption paths work, including the deferred case where the key ARN is unknown at plan.

## Child module (generic, simple): `modules/s3-bucket-encrypted/`
SIMPLIFIED: the module NEVER creates a KMS key. Input `kms_key_arn` (string, default null).
- set  -> validate the ARN via `data.aws_kms_key` and use it for SSE-KMS.
- null -> use S3's default SSE-KMS managed key (`aws/s3`): omit `kms_master_key_id`.

- [ ] `variables.tf`: `bucket_name` (string, req), `kms_key_arn` (string, default null), `tags` (map, default {}).
- [ ] `main.tf`:
  - `locals.use_provided_key = var.kms_key_arn != null`
  - `data "aws_kms_key" "provided"` `count = local.use_provided_key ? 1 : 0`, `key_id = var.kms_key_arn` (validation)
  - `aws_s3_bucket.this`
  - `aws_s3_bucket_public_access_block.this` (all true) — trivy HIGH/CRITICAL clean
  - `aws_s3_bucket_server_side_encryption_configuration.this`: `sse_algorithm = "aws:kms"`, `kms_master_key_id = use_provided_key ? data.aws_kms_key.provided[0].arn : null`, `bucket_key_enabled = true`
- [ ] `outputs.tf`: `bucket_id`, `bucket_arn`, `encryption_kms_key_arn` (null when default managed key).
- Deferred-actions hook: when `var.kms_key_arn` is unknown at plan, `use_provided_key` is unknown -> data-source `count` unknown -> natively deferred (no error). This is the whole point.

## Root module (specific to the use case)
- [ ] `main.tf`:
  - `resource "aws_kms_key" "root"` — the key created in the root.
  - `module "existing_key_bucket"` -> `kms_key_arn = aws_kms_key.root.arn` (ARN unknown at plan -> exercises deferral).
  - `module "managed_key_bucket"`  -> no `kms_key_arn` (module creates its own).
  - bucket names unique & specific: `${var.bucket_prefix}-existing-key` / `${var.bucket_prefix}-managed-key` + random suffix.
- [ ] `variables.tf`: `region` (default eu-west-1), `bucket_prefix` (default e.g. "tf-deferred-demo").
- [ ] `outputs.tf`: both bucket ARNs + both effective KMS ARNs + root KMS ARN.
- [ ] `providers.tf`: drop stale `-allow-deferral`/experiments comment; `required_version = ">= 1.16.0-alpha20260603"`; providers aws >= 5.0 (+ random if suffix kept).

## Docs
- [ ] Rewrite example `README.md`: native behavior (no experiments / no -allow-deferral), the two-instance demo, module contract, run steps. Correct the earlier false `-allow-deferral` claim. Update root README catalogue description if needed.

## Validation (local, before push)
- [ ] `terraform fmt -check -recursive`
- [ ] `terraform validate` on the alpha (via mise) for the root module
- [ ] `tflint` with the example `.tflint.hcl` (aws ruleset, naming conventions)
- [ ] `trivy config` on the example dir -> no HIGH/CRITICAL (S3 public access block, SSE)

## Land
- [ ] Commit A `refactor(deferred-actions): rename example to terraform-deferred-actions` (git mv + doc/catalogue updates already staged).
- [ ] Commit B `feat(terraform-deferred-actions): KMS + generic S3 module, two-instance deferral demo`.
- [ ] Push to PR #10; verify CI green (watch the deferred-actions cell's TF install on the alpha pin).

## Decisions to confirm before coding
1. Bucket name uniqueness: add `random_id` suffix (adds hashicorp/random provider) — recommended for live-demo global uniqueness — vs prefix-only (caller ensures uniqueness).
2. `.terraform-version` currently `v1.16.0-alpha20260603` (leading `v`): strip the `v` (align with mise.toml, de-risk `setup-terraform` install) — recommended — vs keep and verify CI accepts it.
3. Child module name `s3-bucket-encrypted` (generic) — OK?
