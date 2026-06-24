# Demo run-of-show - live "Terraform test" (2026-06-25).
# terraform 1.15.6 (cf .terraform-version). L'apply réel cible le profil AWS sandbox.
TF := terraform

.PHONY: init fmt validate test test-fast test-deploy test-parallel sweep clean

init:          ## init (providers : aws + random)
	$(TF) init

fmt:           ## format check
	$(TF) fmt -recursive -check -diff

validate:      ## validate la config
	$(TF) validate

test-fast:     ## couche creds-free : validations + plan mocké (tourne en CI sans secret)
	$(TF) test -filter=tests/validations.tftest.hcl -filter=tests/plan.tftest.hcl -verbose

test-deploy:   ## integration : apply réel sur AWS (AWS_PROFILE=sandbox requis)
	AWS_PROFILE=sandbox $(TF) test -filter=tests/deploy.tftest.hcl

test-parallel: ## parallel + state_key : 2 déploiements concurrents (AWS_PROFILE=sandbox)
	AWS_PROFILE=sandbox $(TF) test -filter=tests/parallel.tftest.hcl

test:          ## suite complète (AWS_PROFILE=sandbox pour les couches apply)
	AWS_PROFILE=sandbox $(TF) test

sweep:         ## nettoyage des ressources orphelines par tag (cf sweep.sh)
	./sweep.sh

clean:         ## supprime l'état local terraform
	find . -type d -name '.terraform' -prune -exec rm -rf {} + ; find . -name '*.tfstate*' -delete
