# AGENTS.md - terraform-module-testing

Guidance spécifique à cet exemple. Conventions repo : AGENTS.md racine.

Taxonomy: **type lab** - support de live, étapes progressives. Tags: aws, terraform-test, testing, s3, validation, mock, parallel.

## Purpose and scope

Démontrer le framework `terraform test` natif sur un module S3 réutilisable : valider les entrées, faire échouer proprement (`expect_failures`), tester le plan sans cloud (`mock_provider`), déployer pour de vrai et asserter les ressources, paralléliser avec `state_key`. Pédagogique, pas une lib de prod.

## Architecture

- `modules/s3-bucket/` : le module sous test (child). Validations simples (nom S3, environnement) + croisées (chiffrement ⇒ ARN KMS ; prod ⇒ pas de `force_destroy`). Chiffrement KMS conditionnel (`count` sur l'ARN).
- racine (`main.tf` + `providers.tf`) : exemple d'utilisation (root) + `default_tags` de run pour le sweeper.
- `tests/` :
  - `validations.tftest.hcl` : `expect_failures`, plan-only, creds-free (mock).
  - `plan.tftest.hcl` : `mock_provider`, assertions sur la config planifiée, creds-free.
  - `deploy.tftest.hcl` : apply réel (AWS_PROFILE=sandbox), assertions ressources, auto-destroy.
  - `parallel.tftest.hcl` : `parallel` + `state_key`, 2 déploiements concurrents.
  - `setup/` : module helper (suffixe aléatoire pour noms uniques).

## Common commands

```bash
make init
make test-fast                 # creds-free (CI sans secret)
AWS_PROFILE=sandbox make test   # suite complète, apply réel
./sweep.sh                      # nettoyage orphelins par tag (dry-run)
```

## Conventions

- Variables mono-type plutôt qu'objets complexes : isole le message d'erreur de chaque validateur.
- Un `run` atomique par validateur (relecture simple, plan-only peu coûteux).
- `versioning` S3 = `Enabled` / `Suspended` (jamais `Disabled`).
