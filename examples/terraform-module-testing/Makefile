# Demo run-of-show - live "Terraform test" (2026-06-25).
# terraform 1.15.6 (see .terraform-version). The real apply targets the AWS account of $AWS_PROFILE.
# Targets are ordered as the progressive demo stages (read the README "Progressive demo").

.PHONY: init fmt validate test-validate test-plan test-fast test-deploy test-parallel test sweep clean

init:           ## init (providers: aws + random)
	terraform init

fmt:            ## format check
	terraform fmt -recursive -check -diff

validate:       ## validate the config
	terraform validate

test-validate:  ## Stage 1 - variable validations only (expect_failures, creds-free)
	terraform test -filter=tests/validations.tftest.hcl -verbose

test-plan:      ## Stage 2 - mocked plan assertions only (mock_provider, creds-free)
	terraform test -filter=tests/plan.tftest.hcl -verbose

test-fast:      ## Stages 1+2 - creds-free layer (runs in CI without secrets)
	terraform test -filter=tests/validations.tftest.hcl -filter=tests/plan.tftest.hcl -verbose

test-deploy:    ## Stage 3 - integration: real apply on AWS (requires AWS_PROFILE set)
	terraform test -filter=tests/deploy.tftest.hcl

test-parallel:  ## Stage 4 - parallel + state_key: 2 concurrent deployments (requires AWS_PROFILE set)
	terraform test -filter=tests/parallel.tftest.hcl

test:           ## full suite (requires AWS_PROFILE set for the apply stages)
	terraform test

sweep:          ## clean up orphaned resources by tag (see sweep.sh)
	./sweep.sh

clean:          ## remove local terraform state
	find . -type d -name '.terraform' -prune -exec rm -rf {} + ; find . -name '*.tfstate*' -delete
