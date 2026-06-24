# terraform-module-testing

> **type** `lab` · **tags** `aws` `terraform-test` `testing` `s3` `validation` `mock` `parallel`

Tester un module Terraform avec le framework natif `terraform test` : valider les entrées, le casser exprès, le déployer pour de vrai. Support du live "Terraform test" (2026-06-25).

## Le module

`modules/s3-bucket/` crée un bucket S3 avec versioning, blocage des accès publics et chiffrement SSE-KMS conditionnel. Il porte des garde-fous :

- **validations simples** : nom de bucket (règles S3), `environment` (dev/staging/prod) ;
- **validations croisées** (Terraform 1.9+) : `enable_encryption` exige `kms_key_arn` ; `prod` interdit `force_destroy` ;
- **chiffrement conditionnel** : `count = var.kms_key_arn != null ? 1 : 0` (la décision se prend sur la valeur de l'ARN).

## Les tests

| Fichier | command | Cloud | Couvre |
|---|---|---|---|
| `tests/validations.tftest.hcl` | plan | non (mock) | `expect_failures` sur chaque validateur |
| `tests/plan.tftest.hcl` | plan | non (mock) | toutes les variables câblées dans le plan |
| `tests/deploy.tftest.hcl` | apply | oui (sandbox) | déploiement réel + assertions ressources |
| `tests/parallel.tftest.hcl` | apply | oui (sandbox) | `parallel` + `state_key`, 2 déploiements concurrents |

Les deux premières couches tournent **sans credentials** (CI sans secret). Les deux dernières déploient sur un vrai compte (`AWS_PROFILE=sandbox`) et `terraform test` détruit en fin de fichier.

## Lancer

```bash
make init
make test-fast                  # validations + plan mocké (creds-free)
AWS_PROFILE=sandbox make test    # suite complète (apply réel + auto-destroy)
```

## Nettoyage sur crash

Si `terraform test` est interrompu avant son auto-destroy, l'état en mémoire disparaît et les ressources fuient. Chaque ressource porte un tag de suite (`default_tags`), donc un sweeper les retrouve :

```bash
./sweep.sh            # liste les buckets taggés (dry-run)
./sweep.sh --force    # vide + supprime
```

Le natif `skip_cleanup` + `terraform test cleanup` arrive en preview Terraform 1.16.
