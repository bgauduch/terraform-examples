# Demo run-of-show targets - live Terraform deferred actions (2026-06-12).
# The version lives in .terraform-version (01-before/ = 1.15.6, 02-after/ = 1.16-alpha).
# `mise exec -- terraform` reads it (idiomatic version file enabled): same source as
# live typing (cd + bare terraform). Robust in a non-interactive shell (make).
TF := mise exec -- terraform

.PHONY: init versions before-plan before-apply before-destroy after-plan-noflag after-plan after-apply after-destroy clean

init:               ## init both dirs (once, before the demo)
	cd 01-before && $(TF) init
	cd 02-after  && $(TF) init

versions:           ## prove the resolved version per dir (show it on screen)
	cd 01-before && $(TF) version | head -1
	cd 02-after  && $(TF) version | head -1

# --- Segment 2 : 1.15.6 ---
before-plan:        ## 1.15.6 - plan (OK with the boolean ; breaks if switched to arn != null)
	cd 01-before && $(TF) plan
before-apply:       ## 1.15.6 - apply (creates a real KMS key + S3 bucket)
	cd 01-before && $(TF) apply
before-destroy:     ## 1.15.6 - teardown
	cd 01-before && $(TF) destroy

# --- Segment 4 : 1.16 alpha ---
after-plan-noflag:  ## 1.16 - plan WITHOUT the flag -> errors on the unknown value
	cd 02-after && $(TF) plan
after-plan:         ## 1.16 - plan WITH the flag -> deferred changes
	cd 02-after && $(TF) plan -allow-deferral
after-apply:        ## 1.16 - apply (creates a real KMS key + S3 bucket)
	cd 02-after && $(TF) apply -allow-deferral
after-destroy:      ## 1.16 - teardown
	cd 02-after && $(TF) destroy -allow-deferral

clean:              ## remove local terraform state
	find . -type d -name '.terraform' -prune -exec rm -rf {} + ; find . -name '*.tfstate*' -delete
