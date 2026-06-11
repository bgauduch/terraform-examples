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

## Review
(filled on completion)
