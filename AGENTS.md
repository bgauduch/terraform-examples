# AGENTS.md

Guidance for AI coding agents (Claude Code, Cursor, OpenAI Codex, Aider, etc.) working in this repository. A `CLAUDE.md` symlink points here so Claude Code picks it up automatically. Each example also has its own nested `AGENTS.md` with example-specific guidance - read it before editing inside an example.

## What this repo is

A **library of self-contained Terraform examples**. Each lives under `examples/<name>/` and is independent: its own `README.md`, `AGENTS.md`, tooling (`mise.toml`, `.tflint.hcl`) and Terraform root module(s). Examples are **not** factored into shared code - isolation is intentional so each can be read, run, and live-demoed on its own.

Use cases served: reusable patterns, illustrations for blog/LinkedIn posts, and starting points / labs for live tech sessions.

## Taxonomy

Every example declares a primary `type` plus free-form tags. Source of truth is the catalogue table in the root `README.md`; each example's `README.md`/`AGENTS.md` restates its type.

- `pattern` - reusable, production-leaning reference.
- `lab` - starting point / TP with progressive steps for a live session.
- `experiment` - preview/RC features, may be intentionally unstable.

Do **not** create top-level category directories (`patterns/`, `experiments/`...). Keep `examples/` flat and classify via `type` + tags. This avoids lifecycle churn when an example changes category.

## How to add an example (golden path)

1. `mkdir examples/<name>/` - kebab-case, scope-first (`aws-multi-env`, `terraform-rc-variables`).
2. Add `README.md` (state its `type` + tags, objective, run steps, and a closing `## References`
   section) and `AGENTS.md` (example-specific guidance).
   - `## References` is **mandatory**: link the authoritative docs for every mechanism the example
     demonstrates - HashiCorp for language/CLI features, the provider registry for data sources and
     resources, AWS docs for the service behaviour a reader will hit. One line each, saying what
     the link answers rather than repeating its title. Verify each URL resolves before committing:
     these READMEs are read on screen and a 404 is noticed.
   - Keep it distinct from `## Going further`, which cross-references sibling examples and adjacent
     approaches rather than documentation.
   - `## Troubleshooting` is optional in general, and **mandatory for any example creating an
     `aws_cloudwatch_log_group`**: a resolver that blackholes `logs.*` stops the apply halfway with
     a misleading network error. See `tasks/lessons.md` (Local environment) for the bullet to carry.
3. Add per-example tooling: `mise.toml` (pins `terraform`, may be an RC/prerelease for `experiment` types; inherits `tflint`/`trivy` from the repo-root `mise.toml`) and `.tflint.hcl`.
4. Add the Terraform root module(s). Any directory containing a `providers.tf` is auto-discovered by CI - no CI edit needed to validate it.
5. Register a row in the root `README.md` catalogue table.

## CI

`.github/workflows/terraform.yml` auto-discovers Terraform root modules (directories containing `providers.tf`) under `examples/` and runs `validate` + `tflint` + `trivy` per module in a matrix. `terraform fmt -check -recursive` runs once at the root. The `tf-setup` composite action installs the toolchain via `jdx/mise-action` from the target module's merged `mise.toml` (terraform, tflint, trivy). Adding an example requires no CI change.

## Toolchain (mise)

[mise](https://mise.jdx.dev/) is the **single source of truth (SSOT)** for every CLI tool, locally and in CI - there is no separate version file or per-tool CI setup step.

- **Root `mise.toml`** pins the toolchain for the whole repo: `tflint`, `trivy`, and the single `terraform` version every example is tested against. mise merges every `mise.toml` from the cwd up to the repo root, so an example inherits it by default.
- **The floor and the tested version are two different things - do not conflate them.** An example's minimum Terraform version is declared where a reader looks for it: `required_version` in its `.tf`, with a comment naming the feature that sets the floor. The `mise.toml` pin is the version CI and the author actually ran, and it moves forward (Renovate) so a regression in a newer Terraform is caught.
- **A per-example `mise.toml` overrides `terraform` only when the example cannot run on the root version** - e.g. an `experiment` that needs an alpha/rc. Pinning a floor there is a bug: it freezes the example on the oldest supported version and it is never tested against anything else. An example whose `mise.toml` holds only a redundant pin has no reason to exist; keep the file when it carries `[tasks]`.
- **Add a new tool once, in `mise.toml`** (root if repo-wide, example if local). Never re-pin a tool as a CI input - CI installs whatever `mise.toml` declares.
- **Renovate** bumps these via its native `mise` manager; alpha/beta/rc pins (e.g. `experiment` examples) are frozen by a `packageRule` matching `currentValue`.
- **Tasks replace Makefiles**: run with `mise run <task>`, list with `mise tasks`. Each task runs in a subshell, so a task's `cd` (or `dir`) never leaks into your interactive shell.
- **Locally**: `mise install` once, then tools resolve automatically per directory (use `mise exec -- <cmd>`, or activate mise in your shell).

## Repository standards

- **Language**: English everywhere in committed content - code, comments, identifiers, docs, `README.md`, `AGENTS.md`, script output strings. No other language, including inside an example. (This repo is read on screen and public; mixed languages stand out.)
- **Git flow**: GitHub flow (short-lived feature branches off `main`, PR review, squash-merge). Name branches `<type>/<kebab-summary>` where `<type>` is a Conventional Commit type (`feat`, `fix`, `build`, `ci`, `docs`, `chore`, `refactor`, `test`) - e.g. `build/mise-toolchain-ssot` - so branch names stay consistent with commit messages and PR titles.
- **Work tracking**: durable backlog = GitHub Issues + Milestone (a goal + its acceptance criteria); each PR references its issue (`Closes #N`). `main` carries no task file - session plans stay local/ephemeral. `tasks/lessons.md` holds durable repo lessons.
- **Commit messages**: [Conventional Commits](https://www.conventionalcommits.org/) - `<type>(<scope>): <subject>`. Use the example name as scope when relevant (e.g. `feat(aws-multi-env): ...`).
  - Common types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`.
  - Breaking changes: append `!` after type/scope or add a `BREAKING CHANGE:` footer.
  - Keep subject imperative, lowercase, no trailing period, ~72 chars max.
  - **Wrap the body at 100 characters.** `config-conventional` enforces `header-max-length`,
    `body-max-line-length` and `footer-max-line-length`, all at 100 - a single long paragraph line
    fails CI even when the subject is fine. Config: `.commitlintrc.yml`, gate: `commitlint.yml`.
  - Enforced in CI: `commitlint.yml` (commit messages, config-conventional) and `pr-title.yml` (semantic PR title, since squash-merge uses the PR title).
- **Versioning**: [SemVer](https://semver.org/), repo-level single release line via release-please.
- **Validation before commit**: `terraform fmt -recursive` (root) and `terraform validate` inside each touched root module. Optional local mirror of the CI gates lives in `.pre-commit-config.yaml` (fmt/validate/tflint + conventional commit-msg); enable with `pre-commit install --install-hooks && pre-commit install --hook-type commit-msg`.
