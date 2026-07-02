# Mission — Audit à blanc, diff, et système pérenne (run Fable 5)

You are a Staff Platform Engineer, Terraform + AWS expert. A previous audit exists (verdicts per module, reports, machinery in `audit/`). It is content-rich but **unusable by its human owner: too much volume, too shallow on design**. Your mission: re-audit the 11 modules **blind** (without reading the previous conclusions), confront your verdicts with the previous ones, then produce a small set of durable artifacts. Success criteria: (1) the owner reads 3 documents (SYNTHESE part 1, SCORECARD, ADR-001) in 10 minutes and can decide; (2) the design review reaches a depth the owner could NOT produce himself with a scanner and an afternoon.

- Modules: `modules/{acm,cloudfront,ec2,ecr,ecs,eks,elb,rds,s3,security-group,ses}`.
- Deliverables in **French**, machinery in English. Branch `chore/audit-modules`. Conventional Commits in English, no Co-authored-by trailer, simple messages. One commit per milestone; Phase 0 yields three (archive, tooling, results), later phases one each.
- Run autonomously end to end; collect open questions into a final `[⚠️ À VALIDER]` list instead of pausing.
- **Static analysis only**: `terraform init -backend=false` + `validate` at most. Never `plan`/`apply` against a real AWS account; assume zero AWS credentials.

## Blindness contract (R1)

Phase 0 physically archives the previous audit corpus into `audit/_archive/2026-07-opus-run/` **before any analysis**. Until R2 explicitly starts, **never read anything under `audit/_archive/`**. Allowed evidence: module code itself, **in-repo consumer code (`patterns/`, other modules' examples) — consumption patterns are in scope**, `audit/reports/.scans/` (raw scanner JSON), `audit/reports/.metrics/` (metrics pack), `audit/reports/.oss/*.json` (OSS probe records), git history of `modules/`. This blindness is the point: an anchored counter-expertise is worthless.

## Locked decisions (inputs — do not re-litigate)

1. **OSS consumption strategy = vendor + override** as group default (no private Terraform registry at the client, small team). Mandatory guardrails: active upstream drift detection (scheduled job comparing the vendored pin to latest upstream tag), `vendor/` technically locked (CODEOWNERS + CI check, all changes through the sync process), pattern reserved for leaf/shallow modules, **license gate** (upstream license verified compatible with in-repo vendoring — Apache-2.0/MPL-2.0 OK, copyleft/BUSL = blocker; attribution/NOTICE file kept in `vendor/`), **transitive-dependency policy** (upstream module consuming other modules: inject-first — disable the embedded feature and inject the resource as input, e.g. `create_kms_key=false` + key ARN — else scripted transitive vendoring: resolve the tree via `.terraform/modules/modules.json`, rewrite sources, license gate cascades; note inject-first neutralizes runtime creation but NOT the init-time source fetch while the module block exists). Proxy registry = documented target evolution (the internal Artifactory registry distributes the product catalog; what is missing is an OSS proxy remote).
2. **Adoption is not a decision criterion.** The library is a versioned product catalog (semver per module); consumers absorb breaking changes at their own pace. In exchange, any replaced module ships a **migration path**: major release + `moved{}` where possible + short migration guide.
3. Verbosity was the previous failure mode. **Hard output caps are binding**; verify with `wc -l` before committing.

## Decision grid — 4 questions, 4 verdicts

Answered per module, in order, each grounded in the evidence defined below:

- **Q0 — Raison d'être** : ce besoin mérite-t-il un module du catalogue ? (Un wrapper passthrough de 1-3 ressources sans logique ni garde-fous = un pattern documenté suffit peut-être.)
- **Q1 — OSS** : un module OSS de référence sain couvre-t-il le besoin ?
- **Q2 — Wrapper** : le delta interne s'exprime-t-il en wrapper mince au-dessus de cet OSS ? Mince = ≈ < 50 lignes de **logique** (tags, défauts, validations, petite orchestration) ; le pur passthrough de variables/outputs re-déclarées est **exclu du compte**.
- **Q3 — Viabilité** : le code interne est-il assez sain et bien conçu pour valoir son coût de correction et de run ?

Verdict ∈ {`KEEP` (garder, mettre à l'état de l'art), `WRAP-OSS` (remplacer par vendor+override de l'OSS), `REBUILD` (réécrire, OSS absent/mort), `RETIRE` (supprimer le module, documenter un pattern à la place)}. Q0 non → RETIRE. Q1+Q2 oui → WRAP-OSS, **sauf si l'item 10 (trajectoire de possession) ou l'item 2 (immunité cascade-diff déjà payée en interne face à un upstream dense en data sources) penche nettement KEEP — dans ce cas KEEP avec justification explicite chiffrée (coût de migration + sync burden vs coût de run interne)**. Sinon Q3 oui → KEEP, non → REBUILD.

## Evidence model — machines count, agents judge design

### Layer 1 — Deterministic metrics pack (scripted, zero agent tokens)

Write `audit/scripts/metrics.sh` (same style as the existing scan scripts) producing `reports/.metrics/<m>.json` per module:
- `terraform-docs --output json` → inputs/outputs with types, descriptions, defaults; counts: % typed non-`any`, % described, `validation` count, output count vs resource count.
- `terraform init -backend=false && terraform validate` result; `tflint --format=json` error/warning counts.
- Greps (count + locations): `dynamic` blocks per file, `try()`/`lookup()` density, `data` source calls by type, hardcoded `arn:aws`/regions/account IDs, mutable git refs (`ref=` on branches), prod-safety motifs (`skip_final_snapshot`, `apply_immediately`, `recovery_window_in_days = 0`, `force_destroy`, `deletion_protection`, `ignore_changes = all`, `most_recent = true`), `random_`/`time_` resources, `count` on collection-like expressions, `moved{}` blocks presence.
- Lifecycle booleans: `required_version`, bounded provider constraint, lock file, CHANGELOG, semver tags, README, examples/, tests.
- Internal ownership history (`git log -- modules/<m>`): commits over 12/24 months, distinct authors, last-touch age.
Run it on the 11 modules in Phase 0; commit script then results. Subagents READ the pack, they never re-count.

### Layer 2 — Design review (the agents' real job, per module)

Judgment items, each conclusion sourced `file:line`. This is the depth the whole run is paid for:

1. **Structure conventionnelle** — HashiCorp standard module structure; file split coherent; submodules justified (optional feature ≠ code dump); no monster file; one concern per module, granularity right (not a god-module, not an anemic passthrough).
2. **Discipline des data sources** — every `data` call challenged: is it *injectable as a variable* instead (region, partition, account ID, VPC, AMI)? Repeated/looped lookups = plan-time API fan-out (rate-limit risk) → red flag. Non-deterministic lookups (result may change between plans) → red flag. Rule of thumb: leaf modules receive values, compositions perform lookups once. **Cascade-diff assessment (per module, both directions)**: AWS provider 6.x re-evaluates data sources at plan time when a module resource changes, contaminating every derived ARN/policy (perpetual-diff plans). A module that already paid the elimination work (data-free by design, static jsonencode) is immune — credit it, and count the data-source density of the OSS candidate as a re-imported risk / migration cost feeding the KEEP exception in the decision grid.
3. **Interface design** — inputs as intention (objects with optional attrs) vs boolean-flag explosion and parallel lists; dangerous defaults; `validation` where invalid input produces late apply-time failures; outputs minimal and composition-oriented (feed the next module), not passthrough plumbing.
4. **Composition & ownership** — the module owns only its concern's resources; challenge embedded IAM roles/KMS keys/log groups/S3 buckets (should they be inputs?); outputs sufficient to compose without hidden naming contracts between modules. **Dependency tree**: enumerate every `module` block (internal submodules vs external sources); for each external dependency, rule inject / vendor-transitive / refuse per the transitive-dependency policy (ADR-003) — a vendored non-leaf without that ruling = FAIL.
5. **Hidden coupling** — nested `provider` blocks (fatal), `terraform_remote_state` reads, implicit dependencies on external state, `configuration_aliases` documented. **Consumption-pattern audit**: read the in-repo consumers (`patterns/`, sibling examples) — module-level `depends_on` on the module block (defers every internal data source to apply → known-after-apply cascades), hidden ordering contracts, consumer-side workarounds. Root-cause symptoms at the consumer BEFORE crediting internal workarounds as expertise (lesson: the ecs anti-cascade engineering answered a consumer-side `depends_on`, and two independent audits missed it by stopping at the module boundary).
6. **Déterminisme & idempotence** — re-apply with unchanged inputs must produce an empty plan: `random_*`/`time_*` usage, timestamps, unpinned lookups; perpetual-diff constructs.
7. **Sûreté au changement** — `for_each` keys stable under rename (no destroy-on-rename), `create_before_destroy` where replacement hurts, `moved{}` on historical renames, preconditions/postconditions/`check` blocks on load-bearing assumptions, prod-safety motifs from the pack confirmed in context.
8. **Testabilité réelle** — tests assert behavior or merely "plan succeeds"? examples statically sound (init/validate) and covering the main use cases?
9. **Migration cost (only if WRAP-OSS candidate)** — (a) map internal resource addresses to the upstream module's addresses: count 1:1 mappable vs requiring `moved{}`/`import`/state surgery; (b) diff upstream `required_version`/`required_providers` constraints against the internal catalog pins — a forced Terraform or AWS-provider major bump is part of the migration cost. These counts are the factual cost of the OSS switch.
10. **Trajectoire de possession** — the decision compares two futures, price both: KEEP = replicate the underlying AWS service's velocity internally (upstream releases/majors per year from the probe ≈ the labor to match) against the actual internal investment (ownership history from the pack: commits, authors, last touch — orphan module on a fast-moving service = strong OSS signal); WRAP-OSS = vendor sync burden (majors/year to absorb) + upstream risks (license, maintainer concentration). Also count the **reverse gap**: upstream inputs/features absent internally = future consumer asks paid in internal dev vs a free bump.
11. **Reference implementation (mandatory for every WRAP-OSS candidate, optional otherwise)** — fetch the upstream module's source (read-only; external code, outside the blindness contract) and compare implementations of the same concern; ground the state-of-the-art judgment in the concrete alternative, not abstract best practices.

Roll-ups: Q3 = non when validate/correctness or prod-safety FAIL, when critical/high checkov-kics findings remain post-skip-list, or when ≥ 3 design items above are seriously deficient. Q1 from the OSS probe (`health.verdict` MORT/suspect → non; incompatible license → non; input/resource coverage ratios, ≥ ~80% → covering). Q2 from the feature-by-feature delta: any *logic* item (multi-resource orchestration, cross-account wiring, custom IAM trees) or wrapper logic estimate > 50 lines (passthrough excluded) → non.

## Phase 0 — Archive & tooling

0. **Archive first** (dedicated commit): `git mv` the superseded apparatus — `AGENTS.md`, `HANDOFF.md`, `tf-auditor.md` (+ `.opencode/`), `opencode.json`, `reports/*.md`, `reports/*.audit.yaml`, `reports/_TEMPLATE.md`, `reports/_record.schema.yaml`, `SYNTHESE*.md` and `reports/_DECISION-MATRIX.md` (Opus-generated, cites its verdicts) — to `audit/_archive/2026-07-opus-run/`, with a one-line README explaining what it is. Keep live only the deterministic machinery: `scripts/`, `policies/`, `mise.toml`, `reports/.oss/`, `reports/.scans/`.
1. `cd audit && mise trust && mise install`; verify `checkov`, `kics`, `tflint`, `terraform`, `terraform-docs`. Missing → install via mise, never system-wide.
2. Best-practices referential: clone Anton Babenko's terraform-skill to `~/.claude/skills/terraform-skill` (skip if present). Complement with official HashiCorp docs (module composition, standard module structure, `moved` blocks). Cite the practice source when it grounds a judgment.
3. **Scanner noise suppression, versioned**: add a skip-list to `audit/scripts/{checkov,kics}-scan.sh` (checkov `--skip-check`, kics exclude) for the finding families declared out of scope — module-source pinning rules (sources referenced by git tag are accepted practice here; e.g. checkov `CKV_TF_1`/`CKV_TF_2` and kics equivalents — verify IDs) and tagging-policy rules. One-line justification per suppressed ID.
4. Run `audit/scripts/scan-all.sh` only for modules whose `reports/.scans/` output is missing or stale (module code changed since the scan; the injection step targets archived reports — skip or ignore its failures). Write and run `metrics.sh` (Layer 1). OSS probes: reuse `reports/.oss/*.json`, re-run if missing **or older than 30 days**; ensure each probe records the upstream **license**.
5. Commit tooling before results.

## R1 — Blind audit (11/11, full code read)

Parallel subagents by coupling group (coupling is judged together): G1 `security-group, ec2, elb, ecs` · G2 `eks` (own agent) · G3 `rds, s3, ecr` · G4 `acm, cloudfront, ses`. Each subagent gets the blindness contract, the decision grid, its metrics packs, and the Layer 2 checklist:

- Read **all** module files (every `*.tf` incl. submodules, examples, tests, README). Exhaustive coverage, terse restitution — conclusions sourced `file:line`, zero code dumps.
- Work the 11 design items — every item addressed (write `N/A` when genuinely inapplicable), metrics from the pack, judgment from the code.

**Return contract per module: summary ≤ 16 lines — verdict + Q0/Q1/Q2/Q3 (oui/non + 1 line of evidence each) + ownership trajectory (1 line: service velocity vs internal investment) + top 3 design findings + top 3 works to reach state of the art (if KEEP) or migration-cost count (if WRAP-OSS) + effort S/M/L — followed by the design-review table (one row per Layer 2 item: OK/WARN/FAIL + evidence; excluded from the cap).**

**Persist each module record to `audit/reports/<m>.md` (≤ 40 lines: the summary + the design-review table). These 11 records are the evidence trail every verdict must trace to.**

After the groups return, main context runs the **fleet-consistency pass** (cross-module, from metrics packs + interfaces): shared lexicon (same concept = same variable/output name across the 11: tags, naming, ids), homogeneous version constraints, scaffolding drift. Findings feed SYNTHESE part 2 and the works lists.

## R2 — Confrontation (only now, read the previous audit)

1. Load previous verdicts from the archive (`_archive/2026-07-opus-run/`: `*.audit.yaml` reco fields + `SYNTHESE.md` table). Build the diff table: module · previous verdict · blind verdict · agreement?
2. **Convergent modules are settled** — no further work, no prose — except **one convergent module, picked arbitrarily, which gets the same adversarial deep-dive** as a shared-blind-spot check (both runs share scanners and grid; agreement can mean a common blind spot).
3. **Divergent modules**: one targeted deep-dive subagent per divergence, mandate = adversarial (argue BOTH sides on evidence, then conclude). Surface the real conflict; a soft consensus is a failure.
4. Write `audit/CONTRE-EXPERTISE.md` (≤ 80 lines): diff table, per-divergence resolution (≤ 10 lines each), spot-check outcome (1 line), residual `[⚠️ À VALIDER]` for the human.

## R3 — Deliverables & durable system

Survivors outside `_archive/`: the 6 artifacts below + the 11 module records (`audit/reports/<m>.md`) + `audit/CONTRE-EXPERTISE.md`. Nothing else.

1. **`audit/SCORECARD.md`** (≤ 40 lines) — the living view, one row per module: module · verdict · Q0-Q3 · effort · chantiers restants (3 mots) · last-reviewed. Header documents the **re-review ritual**: semestrial or on trigger (new module, upstream major, CVE) → `scan-all.sh` + `metrics.sh` + `oss-probe.sh` + refresh rows via `REVIEW-MODULE.md`.
2. **`audit/SYNTHESE.md`** (rewrite, ≤ 150 lines, hard cap 200) — dual audience. Part 1 (≤ 60 lines, non-tech sponsor, 5-minute read): pourquoi (coût de run d'une petite équipe, risque de dérive), décision d'ensemble, tableau 11 lignes (module · décision · pourquoi en 1 ligne · effort), risques assumés, prochaines étapes ordonnées (quick wins d'abord, dépendances respectées ; **désigner 1 module pilote — le WRAP-OSS le plus simple — pour valider le pattern vendor+override avant toute migration de flotte** ; recommander les scans en CI continue — 1 ligne). Part 2 (équipe) : stratégie OSS en 10 lignes, **stratégie long terme** (la valeur interne se déplace des feuilles — commodités OSS wrappées — vers la couche composition/`patterns/` ; politique de dépréciation des anciens majeurs ; cadence d'upgrade provider), constats flotte, ordre des chantiers, liens SCORECARD/ADRs/archive. Zero scanner IDs in part 1; affirmative phrasing.
3. **`audit/adrs/001-arbitrage-modules.md`** (MADR-lite, ≤ 120 lines): context, the 4-question grid, decision (same 11-row table), consequences (incl. migration paths and RETIRE deprecation plan if any), link to archive for evidence. Status `accepted`, immutable number.
4. **`audit/adrs/002-strategie-consommation-oss.md`** (MADR-lite, ≤ 120 lines): vendor + override by default. Context (no private registry, small team), decision + 4 guardrails (drift detection, locked `vendor/`, leaf-only, license gate + attribution), alternatives considered (proxy registry, pinned git ref, hard fork — one line each on why it lost), consequences (the team owns the run of vendored code, sync process mandatory), evolution path (proxy registry), decision tree for new module needs (OSS-first). You may mine the archived `_DECISION-MATRIX.md` for the strategy model (Source/Distribution/Consumption axes, vendoring guardrails) — rewrite clean, stripped of any reference to the previous run's verdicts. This ADR becomes the strategy SSoT.
5. **`audit/adrs/003-dependances-transitives.md`** (MADR-lite, ≤ 80 lines): policy for upstream modules that consume other modules. Decision: inject-first (disable embedded feature, inject the resource as input) → scripted transitive vendoring as fallback (tree resolved via `.terraform/modules/modules.json`, sources rewritten, license gate cascades) → refuse. Note the inject-first limit (init-time fetch persists while the module block exists); consequences for the sync job (whole tree, not just the root); decision tree per dependency node. References ADR-002, never restates it.
6. **`audit/REVIEW-MODULE.md`** (≤ 60 lines) — the reusable process, distilled from this run: blindness-free single-module audit prompt (4 questions, Layer 1 pack + Layer 2 checklist **including the consumption-pattern check (item 5)**, return contract, module record + scorecard row update). This becomes the methodology SSoT for any new or re-audited module; it references ADR-002 for the strategy, never restates it.

## Verification gates (before final commit)

- SCORECARD verdicts == ADR-001 table == SYNTHESE table == module records (zero drift).
- Line caps respected (`wc -l` each deliverable); French; affirmative phrasing.
- Every verdict traceable to its module record's `file:line` evidence; all 11 design items addressed for all 11 modules; every WRAP-OSS has items 9 (incl. constraint diff) + 11 completed; every divergence resolved or `[⚠️ À VALIDER]`.
- Final message: diff summary previous vs blind run, `[⚠️ À VALIDER]` list, list of evidence gaps (missing probe, tool failure, unscannable module).
